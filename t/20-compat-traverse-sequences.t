# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl base.t'
use strict;
use warnings;

use Test::More tests => 11;

BEGIN {
	use_ok(qw(Algorithm::Diff::Fast), qw(traverse_sequences));
}

my @a = qw(a b c e h j l m n p);
my @b = qw(b c d e f j k l m r s t);
my @correctResult = qw(b c e j l m);
my $correctResult = join(' ', @correctResult);
my $skippedA = 'a h n p';
my $skippedB = 'd f k r s t';

# From the Algorithm::Diff manpage:
my $correctDiffResult = [
	[ [ '-', 0, 'a' ] ],

	[ [ '+', 2, 'd' ] ],

	[ [ '-', 4, 'h' ], 
	  [ '+', 4, 'f' ] ],

	[ [ '+', 6, 'k' ] ],

	[
	  [ '-', 8,  'n' ], 
	  [ '+', 9,  'r' ], 
	  [ '-', 9,  'p' ],
	  [ '+', 10, 's' ],
	  [ '+', 11, 't' ],
	]
];

my ( @matchedA, @matchedB, @discardsA, @discardsB, $finishedA, $finishedB );

sub match
{
	my ( $a, $b ) = @_;
	push ( @matchedA, $a[$a] );
	push ( @matchedB, $b[$b] );
}

sub discard_b
{
	my ( $a, $b ) = @_;
	push ( @discardsB, $b[$b] );
}

sub discard_a
{
	my ( $a, $b ) = @_;
	push ( @discardsA, $a[$a] );
}

sub finished_a
{
	my ( $a, $b ) = @_;
	$finishedA = $a;
}

sub finished_b
{
	my ( $a, $b ) = @_;
	$finishedB = $b;
}

traverse_sequences(
	\@a,
	\@b,
	{
		MATCH     => \&match,
		DISCARD_A => \&discard_a,
		DISCARD_B => \&discard_b
	}
);

is( "@matchedA", $correctResult);
is( "@matchedB", $correctResult);
is( "@discardsA", $skippedA);
is( "@discardsB", $skippedB);

@matchedA = @matchedB = @discardsA = @discardsB = ();
$finishedA = $finishedB = undef;

traverse_sequences(
	\@a,
	\@b,
	{
		MATCH      => \&match,
		DISCARD_A  => \&discard_a,
		DISCARD_B  => \&discard_b,
		A_FINISHED => \&finished_a,
		B_FINISHED => \&finished_b,
	}
);

is( "@matchedA", $correctResult);
is( "@matchedB", $correctResult);
is( "@discardsA", $skippedA);
is( "@discardsB", $skippedB);
is( $finishedA, 9, "index of finishedA" );
is( $finishedB, undef, "index of finishedB" );
