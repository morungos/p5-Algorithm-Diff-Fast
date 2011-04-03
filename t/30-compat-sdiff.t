# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl base.t'
use strict;
$^W++;

use Test::More tests => 13;
use Test::Deep;

BEGIN {
	use_ok(qw(Algorithm::Diff::Fast), qw(sdiff));
}

##################################################
# <Mike Schilli> m@perlmeister.com 03/23/2002: 
# Tests for sdiff-interface
#################################################

my @a = qw(abc def yyy xxx ghi jkl);
my @b = qw(abc dxf xxx ghi jkl);
my $correctDiffResult = [ ['u', 'abc', 'abc'],
                       ['c', 'def', 'dxf'],
                       ['-', 'yyy', ''],
                       ['u', 'xxx', 'xxx'],
                       ['u', 'ghi', 'ghi'],
                       ['u', 'jkl', 'jkl'] ];
my @result = sdiff(\@a, \@b);
cmp_deeply(\@result, $correctDiffResult, "Got correct sdiff result");


#################################################
@a = qw(a b c e h j l m n p);
@b = qw(b c d e f j k l m r s t);
$correctDiffResult = [ ['-', 'a', '' ],
                       ['u', 'b', 'b'],
                       ['u', 'c', 'c'],
                       ['+', '',  'd'],
                       ['u', 'e', 'e'],
                       ['c', 'h', 'f'],
                       ['u', 'j', 'j'],
                       ['+', '',  'k'],
                       ['u', 'l', 'l'],
                       ['u', 'm', 'm'],
                       ['c', 'n', 'r'],
                       ['c', 'p', 's'],
                       ['+', '',  't'],
                     ];
@result = sdiff(\@a, \@b);
cmp_deeply(\@result, $correctDiffResult, "Got correct sdiff result");

#################################################
@a = qw(a b c d e);
@b = qw(a e);
$correctDiffResult = [ ['u', 'a', 'a' ],
                       ['-', 'b', ''],
                       ['-', 'c', ''],
                       ['-', 'd', ''],
                       ['u', 'e', 'e'],
                     ];
@result = sdiff(\@a, \@b);
cmp_deeply(\@result, $correctDiffResult, "Got correct sdiff result");

#################################################
@a = qw(a e);
@b = qw(a b c d e);
$correctDiffResult = [ ['u', 'a', 'a' ],
                       ['+', '', 'b'],
                       ['+', '', 'c'],
                       ['+', '', 'd'],
                       ['u', 'e', 'e'],
                     ];
@result = sdiff(\@a, \@b);
cmp_deeply(\@result, $correctDiffResult, "Got correct sdiff result");

#################################################
@a = qw(v x a e);
@b = qw(w y a b c d e);
$correctDiffResult = [ 
                       ['c', 'v', 'w' ],
                       ['c', 'x', 'y' ],
                       ['u', 'a', 'a' ],
                       ['+', '', 'b'],
                       ['+', '', 'c'],
                       ['+', '', 'd'],
                       ['u', 'e', 'e'],
                     ];
@result = sdiff(\@a, \@b);
cmp_deeply(\@result, $correctDiffResult, "Got correct sdiff result");

#################################################
@a = qw(x a e);
@b = qw(a b c d e);
$correctDiffResult = [ 
                       ['-', 'x', '' ],
                       ['u', 'a', 'a' ],
                       ['+', '', 'b'],
                       ['+', '', 'c'],
                       ['+', '', 'd'],
                       ['u', 'e', 'e'],
                     ];
@result = sdiff(\@a, \@b);
cmp_deeply(\@result, $correctDiffResult, "Got correct sdiff result");

#################################################
@a = qw(a e);
@b = qw(x a b c d e);
$correctDiffResult = [ 
                       ['+', '', 'x' ],
                       ['u', 'a', 'a' ],
                       ['+', '', 'b'],
                       ['+', '', 'c'],
                       ['+', '', 'd'],
                       ['u', 'e', 'e'],
                     ];
@result = sdiff(\@a, \@b);
cmp_deeply(\@result, $correctDiffResult, "Got correct sdiff result");

#################################################
@a = qw(a e v);
@b = qw(x a b c d e w x);
$correctDiffResult = [ 
                       ['+', '', 'x' ],
                       ['u', 'a', 'a' ],
                       ['+', '', 'b'],
                       ['+', '', 'c'],
                       ['+', '', 'd'],
                       ['u', 'e', 'e'],
                       ['c', 'v', 'w'],
                       ['+', '',  'x'],
                     ];
@result = sdiff(\@a, \@b);
cmp_deeply(\@result, $correctDiffResult, "Got correct sdiff result");

#################################################
@a = qw();
@b = qw(a b c);
$correctDiffResult = [ 
                       ['+', '', 'a' ],
                       ['+', '', 'b' ],
                       ['+', '', 'c' ],
                     ];
@result = sdiff(\@a, \@b);
cmp_deeply(\@result, $correctDiffResult, "Got correct sdiff result");

#################################################
@a = qw(a b c);
@b = qw();
$correctDiffResult = [ 
                       ['-', 'a', '' ],
                       ['-', 'b', '' ],
                       ['-', 'c', '' ],
                     ];
@result = sdiff(\@a, \@b);
cmp_deeply(\@result, $correctDiffResult, "Got correct sdiff result");

#################################################
@a = qw(a b c);
@b = qw(1);
$correctDiffResult = [ 
                       ['c', 'a', '1' ],
                       ['-', 'b', '' ],
                       ['-', 'c', '' ],
                     ];
@result = sdiff(\@a, \@b);
cmp_deeply(\@result, $correctDiffResult, "Got correct sdiff result");

#################################################
@a = qw(a b c);
@b = qw(c);
$correctDiffResult = [ 
                       ['-', 'a', '' ],
                       ['-', 'b', '' ],
                       ['u', 'c', 'c' ],
                     ];
@result = sdiff(\@a, \@b);
cmp_deeply(\@result, $correctDiffResult, "Got correct sdiff result");
