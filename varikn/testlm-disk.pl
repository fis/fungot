#! /usr/bin/env perl

# Tests a fungot language model, generates some tokens.
# Disk-based variant of it.

use strict;
use warnings;

# Read command line arguments.

scalar @ARGV >= 2 or die "usage $0 tokens.bin.foo model.bin.fii [count] [prefix ...]";
my ($tokfile, $modelfile, $count, @prefix) = @ARGV;
$count ||= 1;

my ($in, $t);

# Slurp in the token file.

my $tdata = '';

$in = undef;
open $in, '<:raw', $tokfile or die "can't read: $tokfile: $!";
$tdata .= $t while read($in, $t, 65536) > 0;
close $in;

# Generate the inverse token map for parsing the prefix.

my %tokenmap;

if (@prefix)
{
    my $prev_offset = 0;
    my $token = 0;
    while (4*$token < length($tdata)-4)
    {
	my ($len, @offset) = unpack('CCCC', substr($tdata, $token*4, 4));
	my $offset = ($offset[0] << 14) | ($offset[1] << 7) | $offset[2];
	last if $offset+$len > length($tdata) or $offset < $prev_offset;
	$tokenmap{substr($tdata, $offset, $len)} = $token;
      $token++;
    }
}

# Open the model file, define reading tools.

open MODEL, '<:raw', $modelfile or die "can't read: $modelfile: $!";

sub read4
{
    my $file = shift;
    read($file, my $data, 4) == 4 or die "truncated file";
    my @bytes = unpack('CCCC', $data);
    return ($bytes[0] << 21) | ($bytes[1] << 14) | ($bytes[2] << 7) | $bytes[3];
}

sub read_node
{
    my ($at) = @_;

    my $childs = {};
    my $nexts = [];
    my $node = { 'childs' => $childs, 'nexts' => $nexts };

    seek MODEL, $at, 0;

    my $childcount = read4(\*MODEL);
    my @childrec;

    foreach my $i (1 .. $childcount)
    {
	my $t = read4(\*MODEL);
	my $o = read4(\*MODEL);
	push @childrec, [$t, $o];
    }

    my $canstop = getc MODEL;
    $node->{'canstop'} = 1 if $canstop and ord($canstop);

    my $tn = read4(\*MODEL);
    $node->{'totalnext'} = $tn;

    while ($tn > 0)
    {
	my $t = read4(\*MODEL);
	my $c = read4(\*MODEL);
	push @$nexts, [$t, $c];
	$tn -= $c;
    }

    foreach my $cr (@childrec)
    {
	$childs->{$cr->[0]} = $cr->[1];
    }

    return $node;
}

my $tree = read_node(0);

# Generate the starting stage.

my @base = (1); # start token

while (@prefix)
{
    my $word = shift @prefix;
    my $token = $tokenmap{$word};
    print "WARNING: missing token: $word\n" unless defined $token;
    push @base, (defined $token ? $token : 0);
}

# Generate some data.

sub descend
{
    my ($tree, $context, $at) = @_;

    return $tree if $at <= 0;
    my $child = $tree->{'childs'}->{$context->[$at]};
    return $tree unless $child;
    return descend(read_node($child), $context, $at-1);
}

sub token2text
{
    my $token = shift;
    my ($len, @offset) = unpack('CCCC', substr($tdata, $token*4, 4));
    my $offset = ($offset[0] << 14) | ($offset[1] << 7) | $offset[2];
    return substr($tdata, $offset, $len);
}

foreach my $c (1 .. $count)
{
    # Generate a phrase.

    my @phrase = @base; # start token

    while (scalar @phrase < 500 and $phrase[$#phrase] != 2)
    {
	my $prefix = descend($tree, \@phrase, $#phrase);

	if ($prefix->{'canstop'})
	{
	    my $prob = (scalar @phrase)/5 + 1;
	    if (int(rand(20)) < $prob)
	    {
		push @phrase, 2;
		last;
	    }
	}

	my $selcnt = int(rand($prefix->{'totalnext'}));

	foreach my $n (@{$prefix->{'nexts'}})
	{
	    if ($n->[1] > $selcnt)
	    {
		push @phrase, $n->[0];
		last;
	    }

	    $selcnt -= $n->[1];
	}
    }

    push @phrase, 2 unless $phrase[$#phrase] == 2;

    # Convert from integers to tokens.

    $_ = token2text($_) foreach @phrase;

    # Generate text w.r.t. punctuation.

    my %punct_prev = (
	'PDOT' => '.', 'PEXCL' => '!', 'PQUEST' => '?',
	'PCOMMA' => ',', 'PCOLON' => ':', 'PELLIPSIS' => '...',
	'PCDQUOT' => '"', 'PCPAREN' => ')', 'PCSQUOT' => "'"
	);
    my %punct_next = (
	'PODQUOT' => '"', 'POPAREN' => '(', 'POSQUOT' => "'",
	'PHASH' => '#', 'PAT' => '@',
	);
    my %punct_mid = (
        'PSLASH' => '/',
        );
    my %punct_sep = (
	'PSMILE' => ':)', 'PFROWN' => ':(', 'PSEP' => '/'
	);

    my %punct = (
	%punct_prev,
	%punct_next,
        %punct_mid,
	%punct_sep
	);

    my %punct_pairs = (
	'PODQUOT' => 'PCDQUOT', 'POPAREN' => 'PCPAREN', 'POSQUOT' => 'PCSQUOT'
	);
    my %punct_end_pairs = map { $punct_pairs{$_} => $_ } (keys %punct_pairs);

    my $text = '';
    my @punct_stack;

    foreach my $i (0 .. $#phrase)
    {
	my $t = $phrase[$i];

	next if $t eq 'START' or $t eq 'END';

	# When do we need a space? Whenever the previous token does
	# not belong to the punct_next category, and the current token
	# does not belong to the punct_prev category, and neither one
        # belongs to the punct_mid category.

	my $pt = ($i > 0 ? $phrase[$i-1] : 'START');
	if ($pt ne 'START' and not $punct_next{$pt} and not $punct_prev{$t} and not $punct_mid{$pt} and not $punct_mid{$t})
	{
	    $text .= ' ';
	}

	# Handle the punctuation stacking system.

	my $endpunct = $punct_pairs{$t};

	if ($endpunct)
	{
	    # Starting a new punctuated range.
	    push @punct_stack, $endpunct;
	}
	elsif ($punct_end_pairs{$t})
	{
	    # Finishing up a punctuated range. If we can find it in
	    # the stack, we emit the closing punctuation. If not, we
	    # just discard it.

	    my $close_up_to = $#punct_stack;
	    $close_up_to-- while $close_up_to >= 0 and $punct_stack[$close_up_to] ne $t;
	    next if $close_up_to < 0;

	    for (my $pi = $#punct_stack; $pi >= $close_up_to; $pi--)
	    {
		$text .= $punct{$punct_stack[$pi]};
	    }

	    splice @punct_stack, $close_up_to;
	    next;
	}

	# Append the text or punctuation in question.

	$pt = $punct{$t};
	$t = $pt if $pt;

	$text .= $t;
    }

    # Close any remaining punctuation.

    while (my $t = pop @punct_stack)
    {
	$text .= $punct{$t};
    }

    print $text, "\n";
}
