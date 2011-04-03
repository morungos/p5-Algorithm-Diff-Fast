use strict;
use warnings;

use Test::More tests => 3;

BEGIN {
	use_ok(qw(Algorithm::Diff::Fast), qw(LCS_length diff));
}

# We need to build a couple of random sequences, ideally in a safe and predictable manner,
# which is not going to happen smoothly with the built-in rand(). This is based on the
# multiply-with-carry method, and because we use standard initialisations, this will be 
# stable on Perl platforms, or at least, stable enough to build a sensible test set
# dynamically. 

my $m_w = 100;
my $m_z = 101;

sub get_random {
	$m_z = 36969 * ($m_z & 65535) + ($m_z >> 16);
    $m_w = 18000 * ($m_w & 65535) + ($m_w >> 16);
    return ($m_z << 16) + $m_w;
}

sub get_random_list {
	my ($count) = @_;
	return map { get_random() & 0xffff } (1..$count);
}

my @seq1;
my @seq2;

foreach my $count (1..50) {
	my @identical = get_random_list(1000);
	push @seq1, @identical;
	push @seq2, @identical;
	push @seq1, get_random_list(get_random() & 0xff);
	push @seq2, get_random_list(get_random() & 0xff);
}

my $differences = Algorithm::Diff::Fast::LCS_length(\@seq1, \@seq2);
is($differences, 50012, "Found a lot in common");

my @hunks = Algorithm::Diff::Fast::diff(\@seq1, \@seq2);
is(@hunks, 62, "Found diffable hunks");
