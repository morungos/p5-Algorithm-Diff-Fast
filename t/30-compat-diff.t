# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl base.t'
use strict;
use warnings;

use Test::More tests => 2;
use Test::Deep;

BEGIN {
	use_ok(qw(Algorithm::Diff::Fast), qw(diff));
}

my @a = qw(a b c e h j l m n p);
my @b = qw(b c d e f j k l m r s t);

# From the Algorithm::Diff manpage:

# Note: this test was amended as part of Algorithm::Diff::Fast, as the original
# test was actually not from the Algorithm::Diff manpage, but had its order
# rather arbitrarily modified. This is actually the correct order from the manpage
# note that the contents of a hunk cannot always be assumed to be identical to
# Algorithm::Diff for this reason. Algorithm::Diff::Fast always puts deletions 
# before insertions in a hunk. 

my $correctDiffResult = [
	[ [ '-', 0, 'a' ] ],

	[ [ '+', 2, 'd' ] ],

	[ [ '-', 4, 'h' ], 
	  [ '+', 4, 'f' ] ],

	[ [ '+', 6, 'k' ] ],

	[
	  [ '-', 8,  'n' ], 
	  [ '-', 9,  'p' ],
	  [ '+', 9,  'r' ], 
	  [ '+', 10, 's' ],
	  [ '+', 11, 't' ],
	]
];

# Compare the diff output with the one from the Algorithm::Diff manpage.
my $diff = diff( \@a, \@b );
cmp_deeply($diff, $correctDiffResult, "Got correct diff result");
