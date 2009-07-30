#! /usr/bin/env perl

# Converts ARPA format ngram model into the two binary files fungot
# uses for babbling.
#
# For details on the ARPA file format, see:
# http://www.speech.sri.com/projects/srilm/manpages/ngram-format.5.html
#
# The fungot format consists of a token file and a model file. All
# multi-byte integers are written in bigendian notation, using only
# the seven lower bits of each octet to avoid character signedness
# problems.
#
# The token file starts with Nt 4-byte records. The first byte
# indicates the length of the token, while the other three are the
# absolute offset in the token file where the token text bytes
# start. After this table come the token strings concatenated
# together.
#
# The model file has a sort of an inverse tree structure. The tree
# node *-t1-...-tn (where * is the root node) contains counts for all
# (n+1)-grams which have the prefix "tn ... t1". This makes it easy to
# do predicting with backoff. Assume we have a context of "... c-2
# c-1". Start from the root node. If there is a child node for token
# c-1 (which means we have seen some bigrams of the form "c-1 X")
# descend to that node. Again, if *there* is a child node for token
# c-2 (we have seen trigrams "c-2 c-1 X"), keep going. When no
# suitable child is found, use the token list of the current node (and
# their counts) to predict the next word.
#
# The root node of the tree starts at offset 0. Each node starts with
# a four-byte integer indicating the number of child nodes (Nc) in the
# node. This is followed with Nc 8-byte records, consisting of two
# four-byte parts. The first part is the token number, and the second
# part is the absolute offset of the subtree for that token. These
# need to be sorted by the token number, because binary search is
# used.
#
# After the child nodes, there is a single byte denoting whether it
# possible to end a sentence here; that is, we have seen a n-gram for
# this prefix with the END token as the next word. 0 for false, 1 for
# true (can end here). Then comes a 4-byte integer containing the
# total sum of all the word counts for possible next words, and
# finally the possible next words as a set of 8-byte records. In each
# record, the first four bytes are the token id for the next word, and
# the second half is the count for that word.

use strict;
use warnings;

use Encode;

# Read command line arguments.

scalar @ARGV == 3 or die "usage: $0 foo.varikn tokens.bin.foo model.bin.foo";
my ($infile, $tokfile, $modelfile) = @ARGV;

open my $in, '<:utf8', $infile or die "can't read: $infile: $!";

# Make sure the input file is in the ARPA format.

<$in> eq "\\data\\\n" or die "not ARPA format: $infile";

# Read the ngram counts.

my @counts;

while (my $line = <$in>)
{
    chomp $line;
    last if $line eq '';

    $line =~ /^ngram (\d+)=(\d+)$/ or die "bad ngram count: $infile: $line";
    my ($n, $count) = (int($1), int($2));

    $n == (scalar @counts) + 1 or die "unexpected $n-gram count: $infile";
    push @counts, $count;
}

# Read the n-grams into our tree structure.
# While reading the 1-grams, also build the token mapping.

my @tokens =
    (
     'UNK', 'START', 'END',
     'PCDQUOT', 'PCOLON', 'PCOMMA', 'PCPAREN', 'PCSQUOT', 'PDOT', 'PELLIPSIS',
     'PEXCL', 'PFROWN', 'PODQUOT', 'POPAREN', 'POSQUOT', 'PQUEST', 'PSLASH', 'PSMILE'
    );

my %tokenmap = (map { $tokens[$_] => $_ } (0 .. $#tokens));

my $tree = { 'childs' => {}, 'nexts' => [] };

sub tree_make_prefix
{
    my ($tree, $prefix, $first, $last) = @_;
    return $tree if $last < $first;

    my $t = $prefix->[$last];
    my $next = $tree->{'childs'}->{$t};

    unless (defined $next)
    {
	$next = { 'childs' => {}, 'nexts' => [] };
	$tree->{'childs'}->{$t} = $next;
    }

    return tree_make_prefix($next, $prefix, $first, $last-1);
}

foreach my $n (1 .. scalar @counts)
{
    # Read and check the "\n-grams:" header.

    <$in> eq "\\$n-grams:\n" or die "missing $n-gram header: $infile";

    # Read the actual data.

    my $count = $counts[$n-1];

    while (my $line = <$in>)
    {
	chomp $line;
	last if $line eq '';
	die "too many $n-grams: $infile" if --$count < 0;

	$line =~ s{<UNK>}{UNK}g;
	$line =~ s{<s>}{START}g;
	$line =~ s{</s>}{END}g;

	my ($p, @ltok) = split /\s+/, $line;
	scalar @ltok == $n || scalar @ltok == $n+1 or die "bad $n-gram entry: $infile: $line";

	# Add unknown unigrams to the token map.

	if ($n == 1)
	{
	    my $t = $ltok[0];
	    my $i = $tokenmap{$t};
	    unless (defined $i)
	    {
		push @tokens, $t;
		$tokenmap{$t} = $#tokens;
	    }
	}

	# Replace tokens in @ltok with token references.

	foreach my $i (0 .. $n-1)
	{
	    my $ti = $tokenmap{$ltok[$i]};
	    defined $ti or die "token with no unigram: $infile: $ltok[$i]";
	    $ltok[$i] = $ti;
	}

	# Update the ngram tree.

	my $prefix = tree_make_prefix($tree, \@ltok, 0, $n-2);

	if ($ltok[$n-1] == 2) # end token
	{
	    $prefix->{'canstop'} = 1;
	}
	else
	{
	    push @{$prefix->{'nexts'}}, [$ltok[$n-1], $p];
	}
    }

    die "too few $n-grams: $infile: missing $count" if $count > 0;
}

# Just in case: also check the footer.

<$in> eq "\\end\\\n" or die "not ARPA format (bad footer): $infile";

close $in;

# Write the token data file.

my @toffsets;
my $toffset = (scalar @tokens) * 4;

foreach my $i (0 .. $#tokens)
{
    my $t = Encode::encode_utf8($tokens[$i]);
    $tokens[$i] = $t;
    push @toffsets, $toffset;
    $toffset += length($t);
}

my $out;
open $out, '>:raw', $tokfile or die "can't write: $tokfile: $!";

foreach my $i (0 .. $#tokens)
{
    my ($t, $o) = ($tokens[$i], $toffsets[$i]);
    die "too large offset: $o" if ($o >> 21);
    print $out pack('CCCC', length($t), ($o >> 14), (($o >> 7) & 127), ($o & 127));
}

print $out $_ foreach @tokens;

close $out;

# Write the ngram model data file.

sub tree_cleanup
{
    my $tree = shift;
    my $childs = $tree->{'childs'};

    foreach my $child (keys %$childs)
    {
	my $ctree = $childs->{$child};
	if (scalar @{$ctree->{'nexts'}} == 0)
	{
	    delete $childs->{$child};
	    next;
	}

	tree_cleanup($ctree);
    }
}

tree_cleanup($tree);

sub tree_integer_counts
{
    my $tree = shift;
    my $ns = $tree->{'nexts'};

    my $sum = 0;

    foreach my $i (0 .. $#$ns)
    {
	my $n = $ns->[$i];
	my $t = exp($n->[1]);
	$n->[1] = $t;
	$sum += $t;
    }

    my $factor = 134217728/$sum; # 2^27 here
    $sum = 0;

    foreach my $i (0 .. $#$ns)
    {
	my $n = $ns->[$i];
	my $t = int($n->[1] * $factor);
	$n->[1] = $t;
	$sum += $t;
    }

    $tree->{'totalnext'} = $sum;

    tree_integer_counts($_) foreach values %{$tree->{'childs'}};
}

tree_integer_counts($tree);

sub tree_set_offsets
{
    my ($tree, $at) = @_;

    my $childs = $tree->{'childs'};
    my $nexts = $tree->{'nexts'};

    my @childorder = sort { $a <=> $b } keys %$childs;
    $tree->{'childorder'} = \@childorder;

    $tree->{'offset'} = $at;

    my $size = ((scalar keys %$childs) + (scalar @$nexts)) * 8 + 4 + 5;
    $at += $size;

    foreach my $c (@childorder)
    {
	my $ctree = $childs->{$c};
	tree_set_offsets($ctree, $at);
	$at += $ctree->{'size'};
	$size += $ctree->{'size'};
    }

    $tree->{'size'} = $size;
}

tree_set_offsets($tree, 0);

sub put4
{
    my ($file, $i) = @_;
    die "too large number: $i" if ($i >> 28);
    print $file pack('CCCC', ($i >> 21), (($i >> 14) & 127), (($i >> 7) & 127), ($i & 127));
}

sub tree_write
{
    my ($tree, $file) = @_;

    my $childs = $tree->{'childs'};
    my $nexts = $tree->{'nexts'};

    put4($file, scalar keys %$childs);
    
    foreach my $c (@{$tree->{'childorder'}})
    {
	put4($file, $c);
	put4($file, $childs->{$c}->{'offset'});
    }

    print $file pack('C', ($tree->{'canstop'} ? 1 : 0));
    put4($file, $tree->{'totalnext'});

    foreach my $n (@$nexts)
    {
	put4($file, $n->[0]);
	put4($file, $n->[1]);
    }

    tree_write($childs->{$_}, $file) foreach @{$tree->{'childorder'}};
}

$out = undef;
open $out, '>:raw', $modelfile or die "can't write: $modelfile: $!";

tree_write($tree, $out);

close $out;
