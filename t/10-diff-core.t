# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Diff.t'

#########################

use Test::More tests => 13;

BEGIN { use_ok('Algorithm::Diff::Fast') };

# OK, here come the nastier tests. This is basically doing a diff. This is also
# the more inefficient version, which uses a callback.

my @a = qw(1 2 3 5 8 9 11 12 13 15);
my @b = qw(2 3 4 5 6 9 11 12 13 16 17 18);

my $results = {};

Algorithm::Diff::Fast::traverse_balanced(\@a, \@b, {MATCH => sub { $results->{MATCH}++ },
	                                           DISCARD_A => sub { $results->{DISCARD_A}++ },
	                                           DISCARD_B => sub { $results->{DISCARD_B}++ },
	                                           CHANGE => sub { $results->{CHANGE}++ },
											  });

is($results->{MATCH}, 7);
is($results->{DISCARD_A}, 1);
is($results->{DISCARD_B}, 3);
is($results->{CHANGE}, 2);

@b = qw(1 2 3 5 8 9 11 12 13 15);
@a = qw(2 3 4 5 6 9 11 12 13 16 17 18);

$results = {};

Algorithm::Diff::Fast::traverse_balanced(\@a, \@b, {MATCH => sub { $results->{MATCH}++ },
	                                           DISCARD_A => sub { $results->{DISCARD_A}++ },
	                                           DISCARD_B => sub { $results->{DISCARD_B}++ },
	                                           CHANGE => sub { $results->{CHANGE}++ },
											  } );

is($results->{MATCH}, 7);
is($results->{DISCARD_A}, 3);
is($results->{DISCARD_B}, 1);
is($results->{CHANGE}, 2);

@a = qw(A B C E H I K L M O);
@b = qw(B C D E F I K L M P Q R);

$results = {};

Algorithm::Diff::Fast::traverse_balanced(\@a, \@b, {MATCH => sub { $results->{MATCH}++ },
	                                           DISCARD_A => sub { $results->{DISCARD_A}++ },
	                                           DISCARD_B => sub { $results->{DISCARD_B}++ },
	                                           CHANGE => sub { $results->{CHANGE}++ },
											  });

is($results->{MATCH}, 7);
is($results->{DISCARD_A}, 1);
is($results->{DISCARD_B}, 3);
is($results->{CHANGE}, 2);
