use strict;

use Algorithm::Diff::Fast qw(LCS);
use Test::More tests => 4;

# These additional tests are there to check out properties of the equivalence,
# such as key generation functions. These were never really exercised in the 
# Algorithm::Diff test suite. 

my @a = qw(1 2 3 5 8 9 11 12 13 15);
my @b = qw(2 3 4 5 6 9 11 12 13 16 17 18);

my @correctResult = qw(2 3 5 9 11 12 13);
my $correctResult = join(' ', @correctResult);

my @lcs = LCS( \@a, \@b );
is("@lcs", $correctResult, "Got correct LCS");

@a = qw(1 2 3 5 8 9.0 11 12 13 15);
@b = qw(2.0 3 4 5 6 9.0 11 12 13 16 17 18);

@correctResult = qw(3 5 9.0 11 12 13);
$correctResult = join(' ', @correctResult);

@lcs = LCS( \@a, \@b );
is("@lcs", $correctResult, "Got correct LCS");

@a = qw(a b c e h j l m n p);
@b = qw(b c d e f j k l m r s t);

@correctResult = qw(b c e j l m);
$correctResult = join(' ', @correctResult);

@lcs = LCS( \@a, \@b );
is("@lcs", $correctResult, "Got correct LCS");

@a = qw(aa ba ca ea ha ja la ma na pa);
@b = qw(bb cb db eb fb jb kb lb mb rb sb tb);

@correctResult = qw(b c e j l m);
$correctResult = join(' ', @correctResult);

sub _first {
    my ($string) = @_;
    $string =~ s{(?<=.).*}{};
    return $string;
}

@lcs = LCS( \@a, \@b, \&_first );
@lcs = map { _first($_); } @lcs;
is("@lcs", $correctResult, "Got correct LCS");

