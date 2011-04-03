# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl oo.t'
use strict;
use warnings;

use Test::More tests => 970;
use Test::Deep;

BEGIN {
	use_ok(qw(Algorithm::Diff::Fast), qw(sdiff));
}

my( $first, $a, $b, $hunks );
for my $pair (
    [ "a b c   e  h j   l m n p",
      "  b c d e f  j k l m    r s t", 9 ],
    [ "", "", 0 ],
    [ "a b c", "", 1 ],
    [ "", "a b c d", 1 ],
    [ "a b", "x y z", 1 ],
    [ "    c  e   h j   l m n p r",
      "a b c d f g  j k l m      s t", 7 ],
    [ "a b c d",
      "a b c d", 1 ],
    [ "a     d",
      "a b c d", 3 ],
    [ "a b c d",
      "a     d", 3 ],
    [ "a b c d",
      "  b c  ", 3 ],
    [ "  b c  ",
      "a b c d", 3 ],
) {
    ( $a, $b, $hunks )= @$pair;
    my @a = split ' ', $a;
    my @b = split ' ', $b;

    my $d = Algorithm::Diff::Fast->new( \@a, \@b );

    if(  @ARGV  ) {
        print "1: $a$/2: $b$/";
        while( $d->Next() ) {
            printf "%10s %s %s$/",
                join(' ',$d->Items(1)),
                $d->Same() ? '=' : '|',
                join(' ',$d->Items(2));
        }
    }

    is( $d->Base(), 0 );
    is( $d->Base(undef), 0 );
    is( $d->Base(1), 0 );
    is( $d->Base(undef), 1 );
    is( $d->Base(0), 1 );

    ok( ! eval { $d->Diff(); 1 } );
    like( $@, qr/\breset\b/i );
    ok( ! eval { $d->Same(); 1 } );
    like( $@, qr/\breset\b/i );
    ok( ! eval { $d->Items(1); 1 } );
    like( $@, qr/\breset\b/i );
    ok( ! eval { $d->Range(2); 1 } );
    like( $@, qr/\breset\b/i );
    ok( ! eval { $d->Min(1); 1 } );
    like( $@, qr/\breset\b/i );
    ok( ! eval { $d->Max(2); 1 } );
    like( $@, qr/\breset\b/i );
    ok( ! eval { $d->Get('Min1'); 1 } );
    like( $@, qr/\breset\b/i );

    ok( ! $d->Next(0) );
    ok( ! eval { $d->Same(); 1 } );
    like( $@, qr/\breset\b/i );
    is( $d->Next(), 1 )         if  0 < $hunks;
    is( $d->Next(undef), 2 )    if  1 < $hunks;
    is( $d->Next(1), 3 )        if  2 < $hunks;
    is( $d->Next(-1), 2 )       if  1 < $hunks;
    ok( ! $d->Next(-2) );
    ok( ! eval { $d->Same(); 1 } );
    like( $@, qr/\breset\b/i );

    ok( ! $d->Prev(0) );
    ok( ! eval { $d->Same(); 1 } );
    like( $@, qr/\breset\b/i );
    is( $d->Prev(), -1 )        if  0 < $hunks;
    is( $d->Prev(undef), -2 )   if  1 < $hunks;
    is( $d->Prev(1), -3 )       if  2 < $hunks;
    is( $d->Prev(-1), -2 )      if  1 < $hunks;
    ok( ! $d->Prev(-2) );

    is( $d->Next(), 1 )         if  0 < $hunks;
    ok( ! $d->Prev() );
    is( $d->Next(), 1 )         if  0 < $hunks;
    ok( ! $d->Prev(2) );
    is( $d->Prev(), -1 )        if  0 < $hunks;
    ok( ! $d->Next() );
    is( $d->Prev(), -1 )        if  0 < $hunks;
    ok( ! $d->Next(5) );

    is( $d->Next(), 1 )         if  0 < $hunks;
    is( $d->Reset(), $d );
    ok( ! $d->Prev(0) );
    is( $d->Reset(3)->Next(0), 3 )  if  2 < $hunks;
    is( $d->Reset(-2)->Prev(), -3 ) if  2 < $hunks;
    is( $d->Reset(0)->Next(-1), $hunks || !1 );

    my $c = $d->Copy();
    is( $c->Base(), $d->Base() );
    is( $c->Next(0), $d->Next(0) );
    is( $d->Copy(-4)->Next(0),
        $d->Copy()->Reset(-4)->Next(0) );

    $c = $d->Copy( undef, 1 );
    is( $c->Base(), 1 );
    is( $c->Next(0), $d->Next(0) );

    $d->Reset();
    my( @A, @B );
    while( $d->Next() ) {
        if( $d->Same() ) {
            is( $d->Diff(), 0 );
            is( $d->Same(), $d->Range(2) );
            is( $d->Items(2), $d->Range(1) );
            is( "@{[$d->Same()]}",
                "@{[$d->Items(1)]}" );
            is( "@{[$d->Items(1)]}",
                "@{[$d->Items(2)]}" );
            is( "@{[$d->Items(2)]}",
                "@a[$d->Range(1)]" );
            is( "@a[$d->Range(1,0)]",
                "@b[$d->Range(2)]" );
            push @A, $d->Same();
            push @B, @b[$d->Range(2)];
        } else {
            is( $d->Same(), 0 );
            is( $d->Diff() & 1, 1*!!$d->Range(1) );
            is( $d->Diff() & 2, 2*!!$d->Range(2) );
            is( "@{[$d->Items(1)]}",
                "@a[$d->Range(1)]" );
            is( "@{[$d->Items(2)]}",
                "@b[$d->Range(2,0)]" );
            push @A, @a[$d->Range(1)];
            push @B, $d->Items(2);
        }
    }
    is( "@A", "@a" );
    is( "@B", "@b" );

    next   if  ! $hunks;

    is( $d->Next(), 1 );
    { local $^W= 0;
    ok( ! eval { $d->Items(); 1 } ); }
    ok( ! eval { $d->Items(0); 1 } );
    { local $^W= 0;
    ok( ! eval { $d->Range(); 1 } ); }
    ok( ! eval { $d->Range(3); 1 } );
    { local $^W= 0;
    ok( ! eval { $d->Min(); 1 } ); }
    ok( ! eval { $d->Min(-1); 1 } );
    { local $^W= 0;
    ok( ! eval { $d->Max(); 1 } ); }
    ok( ! eval { $d->Max(9); 1 } );

    $d->Reset(-1);
    $c= $d->Copy(undef,1);
    is( "@a[$d->Range(1)]",
        "@{[(0,@a)[$c->Range(1)]]}" );
    is( "@b[$c->Range(2,0)]",
        "@{[(0,@b)[$d->Range(2,1)]]}" );
    is( "@a[$d->Get('min1')..$d->Get('0Max1')]",
        "@{[(0,@a)[$d->Get('1MIN1')..$c->Get('MAX1')]]}" );

    is( "@{[$c->Min(1),$c->Max(2,0)]}",
        "@{[$c->Get('Min1','0Max2')]}" );
    ok( ! eval { scalar $c->Get('Min1','0Max2'); 1 } );
    is( "@{[0+$d->Same(),$d->Diff(),$d->Base()]}",
        "@{[$d->Get(qq<same Diff BASE>)]}" );
    is( "@{[0+$d->Range(1),0+$d->Range(2)]}",
        "@{[$d->Get(qq<Range1 rAnGe2>)]}" );
    { local $^W= 0;
    ok( ! eval { $c->Get('range'); 1 } );
    ok( ! eval { $c->Get('min'); 1 } );
    ok( ! eval { $c->Get('max'); 1 } ); }

}

# $d = Algorithm::Diff->new( \@a, \@b, {KeyGen=>sub...} );

# @cdiffs = compact_diff( \@seq1, \@seq2 );
