# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl base.t'
use strict;
use warnings;

use Test::More tests => 2;
use Test::Deep;

BEGIN {
	use_ok(qw(Algorithm::Diff::Fast), qw(LCS_length));
}

my @a = qw(a b c e h j l m n p);
my @b = qw(b c d e f j k l m r s t);

my @correctResult = qw(b c e j l m);
my $correctResult = join(' ', @correctResult);

my $length = LCS_length( \@a, \@b );
is( $length, 6, "LCS length is 6");
