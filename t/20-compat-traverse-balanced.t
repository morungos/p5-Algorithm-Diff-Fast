# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl base.t'
use strict;
use warnings;

use Test::More tests => 9;

BEGIN {
	use_ok(qw(Algorithm::Diff::Fast), qw(traverse_balanced));
}

#################################################
my @a = qw(a b c);
my @b = qw(a x c);
my $r = "";
traverse_balanced( \@a, \@b, 
                   { MATCH     => sub { $r .= "M @_";},
                     DISCARD_A => sub { $r .= "DA @_";},
                     DISCARD_B => sub { $r .= "DB @_";},
                     CHANGE    => sub { $r .= "C @_";},
                   } );
is($r, "M 0 0C 1 1M 2 2", "Simple difference with change callback");

#################################################
# No CHANGE callback => use discard_a/b instead
@a = qw(a b c);
@b = qw(a x c);
$r = "";
traverse_balanced( \@a, \@b, 
                   { MATCH     => sub { $r .= "M @_";},
                     DISCARD_A => sub { $r .= "DA @_";},
                     DISCARD_B => sub { $r .= "DB @_";},
                   } );
is($r, "M 0 0DA 1 1DB 2 1M 2 2", "Simple difference without change callback");

#################################################
@a = qw(a x y c);
@b = qw(a v w c);
$r = "";
traverse_balanced( \@a, \@b, 
                   { MATCH     => sub { $r .= "M @_";},
                     DISCARD_A => sub { $r .= "DA @_";},
                     DISCARD_B => sub { $r .= "DB @_";},
                     CHANGE    => sub { $r .= "C @_";},
                   } );
is($r, "M 0 0C 1 1C 2 2M 3 3", "Difference of two elements with change callback");

#################################################
@a = qw(x y c);
@b = qw(v w c);
$r = "";
traverse_balanced( \@a, \@b, 
                   { MATCH     => sub { $r .= "M @_";},
                     DISCARD_A => sub { $r .= "DA @_";},
                     DISCARD_B => sub { $r .= "DB @_";},
                     CHANGE    => sub { $r .= "C @_";},
                   } );
is($r, "C 0 0C 1 1M 2 2", "Initial difference of two elements with change callback");

#################################################
@a = qw(a x y z);
@b = qw(b v w);
$r = "";
traverse_balanced( \@a, \@b, 
                   { MATCH     => sub { $r .= "M @_";},
                     DISCARD_A => sub { $r .= "DA @_";},
                     DISCARD_B => sub { $r .= "DB @_";},
                     CHANGE    => sub { $r .= "C @_";},
                   } );
is($r, "C 0 0C 1 1C 2 2DA 3 3", "Completely different sequences of different lengths");

#################################################
@a = qw(a z);
@b = qw(a);
$r = "";
traverse_balanced( \@a, \@b, 
                   { MATCH     => sub { $r .= "M @_";},
                     DISCARD_A => sub { $r .= "DA @_";},
                     DISCARD_B => sub { $r .= "DB @_";},
                     CHANGE    => sub { $r .= "C @_";},
                   } );
is($r, "M 0 0DA 1 1", "One additional element suffix");

#################################################
@a = qw(z a);
@b = qw(a);
$r = "";
traverse_balanced( \@a, \@b, 
                   { MATCH     => sub { $r .= "M @_";},
                     DISCARD_A => sub { $r .= "DA @_";},
                     DISCARD_B => sub { $r .= "DB @_";},
                     CHANGE    => sub { $r .= "C @_";},
                   } );
is($r, "DA 0 0M 1 0", "One additional element prefix");

#################################################
@a = qw(a b c);
@b = qw(x y z);
$r = "";
traverse_balanced( \@a, \@b, 
                   { MATCH     => sub { $r .= "M @_";},
                     DISCARD_A => sub { $r .= "DA @_";},
                     DISCARD_B => sub { $r .= "DB @_";},
                     CHANGE    => sub { $r .= "C @_";},
                   } );
is($r, "C 0 0C 1 1C 2 2", "Totally different sequences, same length");
