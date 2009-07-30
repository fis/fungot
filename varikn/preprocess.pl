#! /usr/bin/env perl

# preprocess.pl: tokenizer for fungot babble.

use strict;
use warnings;

my %endpunct = (
	')' => 'PCPAREN',
	'.' => 'PDOT', ',' => 'PCOMMA', ':' => 'PCOLON',
	'?' => 'PQUEST', '!' => 'PEXCL',
	'"' => 'PCDQUOT', '\'\'' => 'PCDQUOT', '\'' => 'PCSQUOT',
	'..' => 'PELLIPSIS', '...' => 'PELLIPSIS',
);
my $endpunctre = qr/[),:?!"]|''?|\.{1,3}/;

my %startpunct = (
	'(' => 'POPAREN',
	'"' => 'PODQUOT', '``' => 'PODQUOT', '\'' => 'POSQUOT',
);
my $startpunctre = qr/[("']|``/;

my %midpunct = (
	'/' => 'PSLASH',
);
my $midpunctre = qr#/#;

my %seppunct = (
	':)' => 'PSMILE', ':-)' => 'PSMILE',
	':(' => 'PFROWN', ':-(' => 'PFROWN',
);
my $seppunctre = qr/:-?[()]/;

my $badcharre = qr'[@{}\[\]#$\\^~<>|]';

# read logs

while (<>) {
	chomp;

	my $text = lc($_);
	$text =~ s/^\s*//;
	$text =~ s/\s*$//;

	next unless $text =~ m#^(?:\w|$startpunctre)#o; # cleanup

	# $text =~ s/^\S+[;:,]\s+//; # strip attributions

	# convert punctuation

	my $itlimit;

	$itlimit = 5;
	while ($text =~ s/(^|\s)($seppunctre)(\s|$)/$1$seppunct{$2}$3/og) {
		# Iterate.
		last unless --$itlimit;
	}

	$itlimit = 5;
	while ($text =~ s/(^|\s)($startpunctre)/$1$startpunct{$2} /og) {
		# Iterate.
		last unless --$itlimit;
	}

	$itlimit = 5;
	while ($text =~ s/($endpunctre)(\s|$)/ $endpunct{$1}$2/og) {
		# Iterate.
		last unless --$itlimit;
	}

	$text =~ s/(\w)($midpunctre)(\w)/$1 $midpunct{$2} $3/og;

	# split text to words

	my @ok;
	foreach my $word (split /\s+/, $text) {
		$word =~ s/^($seppunctre)$/$seppunct{$1}/o;
		$word =~ s/$badcharre//go;
		$word = substr($word, 0, 100); # trim a bit
		next unless $word =~ /\w/;
		push @ok, $word if $word =~ /\w/;
	}
	next if $#ok < 2;

	# disallow horrible strings of punctuation

	my $cpunct = 0;
	foreach my $w (@ok) {
		if ($w =~ /^P/) {
			$cpunct++;
			last if $cpunct > 3;
		} else {
			$cpunct = 0;
		}
	}
	next if $cpunct > 3;

	# add to list

	print join(' ', @ok), "\n";
}
