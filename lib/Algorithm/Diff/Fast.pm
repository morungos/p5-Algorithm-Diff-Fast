package Algorithm::Diff::Fast;

# Copyright (c) 2010 Stuart Watt <stuart@morungos.com>
#
# The MIT License
# 
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.

use 5.010000;
use strict;
use warnings;
use Carp;

use base qw(Exporter);
our @EXPORT_OK = qw(traverse_balanced traverse_sequences LCS LCS_length LCSidx diff sdiff compact_diff);

use integer;
use feature qw(switch);

# First of all, let's do a diff. 

sub traverse_sequences {
    my ($sequence1, $sequence2, $callbacks) = @_;
    my $index1 = 0;
    my $index2 = 0;
    my $match_callback = $callbacks->{MATCH};
    my $discard_a_callback = $callbacks->{DISCARD_A};
    my $discard_b_callback = $callbacks->{DISCARD_B};
    my $finished_a_callback = $callbacks->{A_FINISHED};
    my $finished_b_callback = $callbacks->{B_FINISHED};
    
    my $result = _diff_internal($sequence1, $sequence2);
    
    my $end1 = $#$sequence1;
    my $end2 = $#$sequence2;
    
    foreach my $element (@$result) {
        my ($type, $offset, $length) = @$element;
        given($type) {
            when(1) {
                # This is a match
                for(my $i = 0; $i < $length; $i++) {
###                    print STDERR "MATCH      $index1 - $index2\n";
                    &$match_callback($index1, $index2) if ($match_callback);
                    $index1++;
                    $index2++;
                }
            }
            when(2) {
                # This is a delete
                for(my $i = 0; $i < $length; $i++) {
                    if ($index2 > $end2 && $finished_b_callback) {
###                        print STDERR "FINISH_B   $index1 - $index2\n";
                        &$finished_b_callback($index1);
                        undef($finished_b_callback);    
                    }
                    if ($discard_a_callback) {
###                        print STDERR "DISCARD_A  $index1 - $index2\n";
                        &$discard_a_callback($index1, $index2);
                    }
                    $index1++;
                }
            }
            when(3) {
                # This is an insert
                for(my $i = 0; $i < $length; $i++) {
                    if ($index1 > $end1 && $finished_a_callback) {
###                        print STDERR "FINISH_A   $index1 - $index2\n";
                        &$finished_a_callback($index2);
                        undef($finished_a_callback);    
                    }
                    if ($discard_b_callback) {
###                        print STDERR "DISCARD_B  $index1 - $index2\n";
                        &$discard_b_callback($index1, $index2);
                    }
                    $index2++;
                }
            }
            default {
                croak("Internal error: invalid match type: $type");    
            }
        }
    }
    return;
}

sub traverse_balanced {
    my ($sequence1, $sequence2, $callbacks) = @_;
    my $index1 = 0;
    my $index2 = 0;
    
    my $match_callback = $callbacks->{MATCH};
    my $change_callback = $callbacks->{CHANGE};
    my $discard_a_callback = $callbacks->{DISCARD_A};
    my $discard_b_callback = $callbacks->{DISCARD_B};
    
    my $result = _diff_internal($sequence1, $sequence2);
    my $pending_deletion = undef;
    
    my $flush = sub {
        if ($pending_deletion) {
            for(my $i = 0; $i < $pending_deletion; $i++) {
###                print STDERR "DISCARD_A $index1 - $index2\n";
                &$discard_a_callback($index1, $index2) if ($discard_a_callback);
                $index1++;
            }
        };
        $pending_deletion = undef;
    };
    
    foreach my $element (@$result) {
        my ($type, $offset, $length) = @$element;
        given($type) {
            when(1) {
                # This is a match. If we are following a straight deletion, we can
                # flush it. 
                &$flush();
                for(my $i = 0; $i < $length; $i++) {
###                    print STDERR "MATCH     $index1 - $index2\n";
                    &$match_callback($index1, $index2) if ($match_callback);
                    $index1++;
                    $index2++;
                }
            }
            when(2) {
                # This is a delete (A only). If we are following an earlier deletion, we 
                # should simply add to it. 
                $pending_deletion += $length;
            }
            when(3) {
                # This is an insert (B only). If we are following an earlier deletion, we
                # should interpret this as a change, and consider the change, followed by
                # either a deletion or insertion as appropriate. 
                if ($change_callback && $pending_deletion) {
                    
                    my $changed = ($length < $pending_deletion) ? $length : $pending_deletion;
                    for(my $i = 0; $i < $changed; $i++) {
###                        print STDERR "CHANGE    $index1 - $index2\n";
                        &$change_callback($index1, $index2) if ($change_callback);
                        $index1++;
                        $index2++;
                    }
                    
                    # Now we have done the change, we need now to either do a DISCARD_B or a 
                    # DISCARD_A
                    
                    my $residue = $pending_deletion - $length;
                    if ($residue > 0) {
                        # The deletion is longer
                        for(my $i = 0; $i < $residue; $i++) {
                            &$discard_a_callback($index1, $index2) if ($discard_a_callback);
                            $index1++;
                        }
                    } elsif ($residue < 0) {
                        # The insertion is longer
                        $residue = -$residue;
                        for(my $i = 0; $i < $residue; $i++) {
                            &$discard_b_callback($index1, $index2) if ($discard_b_callback);
                            $index2++;
                        }
                    }

                    $pending_deletion = undef;
                                        
                } else {
                    
                    # If we have some pending deletions, we need to do something like
                    # we do for a change, but interweaving the discards from A and B.
                    
                    &$flush();
                    for(my $i = 0; $i < $length; $i++) {
###                        print STDERR "DISCARD_B $index1 - $index2\n";
                        &$discard_b_callback($index1, $index2) if ($discard_b_callback);
                        $index2++;
                    }
                }                
            }
            default {
                croak("Internal error: invalid match type: $type");    
            }
        }
    }
    
    &$flush();
    
    return;
}

sub prepare {
    my ($a, $keygen, @args) = @_;
    
    if (! defined($keygen)) {
        return { keys =>   $a,
                 values => $a };
    } else {
        return { keys => [ map { &$keygen($_, @args) } @$a ],
                 values => $a };
    }
}

sub _comparable_sequence {
    my ($sequence, $keygen, @args) = @_; 
    
    my $compare;
    if (ref($sequence) eq 'HASH') {
        $compare = $sequence->{keys};
        $sequence = $sequence->{values};
    } elsif (ref($keygen) eq 'CODE') {
        $compare = [ map { &$keygen($_, @args) } @$sequence ];
    } else{
        $compare = $sequence;
    }
    
    return ($compare, $sequence);
}

sub LCS {
    my ($sequence1, $sequence2, $keygen, @args) = @_;
    my $index1 = 0;
    my $index2 = 0;
    my $compare1;
    my $compare2;
    
    ($compare1, $sequence1) = _comparable_sequence($sequence1, $keygen, @args);
    ($compare2, $sequence2) = _comparable_sequence($sequence2, $keygen, @args);
    
    my $result = _diff_internal($compare1, $compare2);
    my @values = ();
    
    foreach my $element (@$result) {
        my ($type, $offset, $length) = @$element;
        given($type) {
            when(1) {
                # This is a match
                for(my $i = 0; $i < $length; $i++) {
                    push @values, $sequence1->[$index1];
                    $index1++;
                    $index2++;
                }
            }
            when(2) {
                # This is a delete
                $index1 += $length;
            }
            when(3) {
                # This is a delete
                $index2 += $length;
            }
        }
    }
    
    return @values;
}

sub LCS_length {
    my ($sequence1, $sequence2, $keygen, @args) = @_;
    
    my $compare1;
    my $compare2;
    ($compare1, $sequence1) = _comparable_sequence($sequence1, $keygen, @args);
    ($compare2, $sequence2) = _comparable_sequence($sequence2, $keygen, @args);
    
    my $result = _diff_internal($compare1, $compare2);
    my $count = 0;
    
    foreach my $element (@$result) {
        my ($type, $offset, $length) = @$element;
        given($type) {
            when(1) {
                $count += $length;
            }
        }
    }
    
    return $count;
}

sub LCSidx {
    my ($sequence1, $sequence2, $keygen, @args) = @_;
    my $index1 = 0;
    my $index2 = 0;
    
    my $compare1;
    my $compare2;
    ($compare1, $sequence1) = _comparable_sequence($sequence1, $keygen, @args);
    ($compare2, $sequence2) = _comparable_sequence($sequence2, $keygen, @args);
    
    my $result = _diff_internal($compare1, $compare2);
    my @indices1 = ();
    my @indices2 = ();
    
    foreach my $element (@$result) {
        my ($type, $offset, $length) = @$element;
        given($type) {
            when(1) {
                # This is a match
                for(my $i = 0; $i < $length; $i++) {
                    push @indices1, $index1;
                    push @indices2, $index2;
                    $index1++;
                    $index2++;
                }
            }
            when(2) {
                # This is a delete
                $index1 += $length;
            }
            when(3) {
                # This is a delete
                $index2 += $length;
            }
        }
    }
    
    return (\@indices1, \@indices2);
}

sub diff {
    my ($a, $b, @args) = @_;
    my $retval = [];
    my $hunk   = [];
    my $discard = sub {
        push @$hunk, [ '-', $_[0], $a->[ $_[0] ] ];
    };
    my $add = sub {
        push @$hunk, [ '+', $_[1], $b->[ $_[1] ] ];
    };
    my $match = sub {
        push @$retval, $hunk if 0 < @$hunk;
        $hunk = []
    };
    traverse_sequences($a, $b,
        { MATCH => $match, DISCARD_A => $discard, DISCARD_B => $add }, @args);
    &$match();
    return wantarray ? @$retval : $retval;
}

sub sdiff {
    my ($a, $b, @args) = @_;
    my $retval = [];
    my $discard = sub { push ( @$retval, [ '-', $a->[ $_[0] ], "" ] ) };
    my $add = sub { push ( @$retval, [ '+', "", $b->[ $_[1] ] ] ) };
    my $change = sub {
        push ( @$retval, [ 'c', $a->[ $_[0] ], $b->[ $_[1] ] ] );
    };
    my $match = sub {
        push ( @$retval, [ 'u', $a->[ $_[0] ], $b->[ $_[1] ] ] );
    };
    traverse_balanced($a, $b, {
            MATCH     => $match,
            DISCARD_A => $discard,
            DISCARD_B => $add,
            CHANGE    => $change,
        }, @args);
    return wantarray ? @$retval : $retval;
}

sub compact_diff {
    my ($a, $b, @args) = @_;
    my ($am, $bm) = LCSidx($a, $b, @args);
    my @cdiff;
    my ($ai, $bi) = (0, 0);
    push @cdiff, $ai, $bi;
    while(1) {
        while(@$am && $ai == $am->[0] && $bi == $bm->[0]) {
            shift @$am;
            shift @$bm;
            ++$ai, ++$bi;
        }
        push @cdiff, $ai, $bi;
        last   if  ! @$am;
        $ai = $am->[0];
        $bi = $bm->[0];
        push @cdiff, $ai, $bi;
    }
    push @cdiff, 0+@$a, 0+@$b
        if  $ai < @$a || $bi < @$b;
    return wantarray ? @cdiff : \@cdiff;
}

require XSLoader;
XSLoader::load(__PACKAGE__, $Algorithm::Diff::Fast::VERSION // 0.01);

########################################
my $Root= __PACKAGE__;
package Algorithm::Diff::Fast::_impl;
use strict;

sub _Idx()  { 0 } # $me->[_Idx]: Ref to array of hunk indices
            # 1   # $me->[1]: Ref to first sequence
            # 2   # $me->[2]: Ref to second sequence
sub _End()  { 3 } # $me->[_End]: Diff between forward and reverse pos
sub _Same() { 4 } # $me->[_Same]: 1 if pos 1 contains unchanged items
sub _Base() { 5 } # $me->[_Base]: Added to range's min and max
sub _Pos()  { 6 } # $me->[_Pos]: Which hunk is currently selected
sub _Off()  { 7 } # $me->[_Off]: Offset into _Idx for current position
sub _Min() { -2 } # Added to _Off to get min instead of max+1

sub Die
{
    require Carp;
    Carp::confess( @_ );
}

sub _ChkPos
{
    my( $me )= @_;
    return   if  $me->[_Pos];
    my $meth= ( caller(1) )[3];
    Die( "Called $meth on 'reset' object" );
}

sub _ChkSeq
{
    my( $me, $seq )= @_;
    
    # This line added as part of Algorithm::Diff::Fast, as the tests allow a missing
    # value here. I have no idea why the tests allow a missing value, as the behaviour
    # here is pretty complicated.
    
    $seq = 0 if (! defined($seq));
    
    return $seq + $me->[_Off]
        if  1 == $seq  ||  2 == $seq;
    my $meth= ( caller(1) )[3];
    Die( "$meth: Invalid sequence number ($seq); must be 1 or 2" );
}

sub getObjPkg
{
    my( $us )= @_;
    return ref $us   if  ref $us;
    return $us . "::_obj";
}

sub new
{
    my( $us, $seq1, $seq2, $opts ) = @_;
    my @args;
    for( $opts->{keyGen} ) {
        push @args, $_   if  $_;
    }
    for( $opts->{keyGenArgs} ) {
        push @args, @$_   if  $_;
    }
    my $cdif= Algorithm::Diff::Fast::compact_diff( $seq1, $seq2, @args );
    my $same= 1;
    if(  0 == $cdif->[2]  &&  0 == $cdif->[3]  ) {
        $same= 0;
        splice @$cdif, 0, 2;
    }
    my @obj= ( $cdif, $seq1, $seq2 );
    $obj[_End] = (1+@$cdif)/2;
    $obj[_Same] = $same;
    $obj[_Base] = 0;
    my $me = bless \@obj, $us->getObjPkg();
    $me->Reset( 0 );
    return $me;
}

sub Reset
{
    my( $me, $pos )= @_;
    $pos= int( $pos || 0 );
    $pos += $me->[_End]
        if  $pos < 0;
    $pos= 0
        if  $pos < 0  ||  $me->[_End] <= $pos;
    $me->[_Pos]= $pos || !1;
    $me->[_Off]= 2*$pos - 1;
    return $me;
}

sub Base
{
    my( $me, $base )= @_;
    my $oldBase= $me->[_Base];
    $me->[_Base]= 0+$base   if  defined $base;
    return $oldBase;
}

sub Copy
{
    my( $me, $pos, $base )= @_;
    my @obj= @$me;
    my $you= bless \@obj, ref($me);
    $you->Reset( $pos )   if  defined $pos;
    $you->Base( $base );
    return $you;
}

sub Next {
    my( $me, $steps )= @_;
    $steps= 1   if  ! defined $steps;
    if( $steps ) {
        my $pos= $me->[_Pos];
        my $new= $pos + $steps;
        $new= 0   if  $pos  &&  $new < 0;
        $me->Reset( $new )
    }
    return $me->[_Pos];
}

sub Prev {
    my( $me, $steps )= @_;
    $steps= 1   if  ! defined $steps;
    my $pos= $me->Next(-$steps);
    $pos -= $me->[_End]   if  $pos;
    return $pos;
}

sub Diff {
    my( $me )= @_;
    $me->_ChkPos();
    return 0   if  $me->[_Same] == ( 1 & $me->[_Pos] );
    my $ret= 0;
    my $off= $me->[_Off];
    for my $seq ( 1, 2 ) {
        $ret |= $seq
            if  $me->[_Idx][ $off + $seq + _Min ]
            <   $me->[_Idx][ $off + $seq ];
    }
    return $ret;
}

sub Min {
    my( $me, $seq, $base )= @_;
    $me->_ChkPos();
    my $off= $me->_ChkSeq($seq);
    $base= $me->[_Base] if !defined $base;
    return $base + $me->[_Idx][ $off + _Min ];
}

sub Max {
    my( $me, $seq, $base )= @_;
    $me->_ChkPos();
    my $off= $me->_ChkSeq($seq);
    $base= $me->[_Base] if !defined $base;
    return $base + $me->[_Idx][ $off ] -1;
}

sub Range {
    my( $me, $seq, $base )= @_;
    $me->_ChkPos();
    my $off = $me->_ChkSeq($seq);
    if( !wantarray ) {
        return  $me->[_Idx][ $off ]
            -   $me->[_Idx][ $off + _Min ];
    }
    $base= $me->[_Base] if !defined $base;
    return  ( $base + $me->[_Idx][ $off + _Min ] )
        ..  ( $base + $me->[_Idx][ $off ] - 1 );
}

sub Items {
    my( $me, $seq )= @_;
    $me->_ChkPos();
    my $off = $me->_ChkSeq($seq);
    if( !wantarray ) {
        return  $me->[_Idx][ $off ]
            -   $me->[_Idx][ $off + _Min ];
    }
    return
        @{$me->[$seq]}[
                $me->[_Idx][ $off + _Min ]
            ..  ( $me->[_Idx][ $off ] - 1 )
        ];
}

sub Same {
    my( $me )= @_;
    $me->_ChkPos();
    return wantarray ? () : 0
        if  $me->[_Same] != ( 1 & $me->[_Pos] );
    return $me->Items(1);
}

my %getName;
BEGIN {
    %getName= (
        same => \&Same,
        diff => \&Diff,
        base => \&Base,
        min  => \&Min,
        max  => \&Max,
        range=> \&Range,
        items=> \&Items, # same thing
    );
}

sub Get
{
    my $me= shift @_;
    $me->_ChkPos();
    my @value;
    for my $arg (  @_  ) {
        for my $word (  split ' ', $arg  ) {
            my $meth;
            if(     $word !~ /^(-?\d+)?([a-zA-Z]+)([12])?$/
                ||  not  $meth= $getName{ lc $2 }
            ) {
                Die( $Root, ", Get: Invalid request ($word)" );
            }
            my( $base, $name, $seq )= ( $1, $2, $3 );
            push @value, scalar(
                4 == length($name)
                    ? $meth->( $me )
                    : $meth->( $me, $seq, $base )
            );
        }
    }
    if(  wantarray  ) {
        return @value;
    } elsif(  1 == @value  ) {
        return $value[0];
    }
    Die( 0+@value, " values requested from ",
        $Root, "'s Get in scalar context" );
}


my $Obj= getObjPkg($Root);
no strict 'refs';

for my $meth (  qw( new getObjPkg )  ) {
    *{$Root."::".$meth} = \&{$meth};
    *{$Obj ."::".$meth} = \&{$meth};
}
for my $meth (  qw(
    Next Prev Reset Copy Base Diff
    Same Items Range Min Max Get
    _ChkPos _ChkSeq
)  ) {
    *{$Obj."::".$meth} = \&{$meth};
}


1;

=head1 NAME

Algorithm::Diff::Fast - Efficiently computes differences between files / lists

=head1 SYNOPSIS

    use Algorithm::Diff::Fast qw(
        LCS LCS_length LCSidx
        diff sdiff compact_diff
        traverse_sequences traverse_balanced );

    @lcs    = LCS( \@seq1, \@seq2 );
    $lcsref = LCS( \@seq1, \@seq2 );
    $count  = LCS_length( \@seq1, \@seq2 );

    ( $seq1idxref, $seq2idxref ) = LCSidx( \@seq1, \@seq2 );


    # Complicated interfaces:

    @diffs  = diff( \@seq1, \@seq2 );

    @sdiffs = sdiff( \@seq1, \@seq2 );

    @cdiffs = compact_diff( \@seq1, \@seq2 );

    traverse_sequences(
        \@seq1,
        \@seq2,
        {   MATCH     => \&callback1,
            DISCARD_A => \&callback2,
            DISCARD_B => \&callback3,
        },
        \&key_generator,
        @extra_args,
    );

    traverse_balanced(
        \@seq1,
        \@seq2,
        {   MATCH     => \&callback1,
            DISCARD_A => \&callback2,
            DISCARD_B => \&callback3,
            CHANGE    => \&callback4,
        },
        \&key_generator,
        @extra_args,
    );
    
    # Object oriented interface
    
    my $diff = Algorithm::Diff->new( \@seq1, \@seq2 );
    $diff->Base( 1 ); 
    while(  $diff->Next()  ) {
        next   if  $diff->Same();
    }

=head1 DESCRIPTION

This module is a drop-in replacement for L<Algorithm::Diff>, but uses C code internally
to make the computations more efficient. It also uses an updated algorithm, essentially
the same algorithm used by GNU's diff command-line utility. This is far more efficient,
especially for large data sets. 

The underlying C code came from libmba (see: http://www.ioplex.com/~miallen/libmba/),
although this module only includes the parts of this library needed to support the diff
implementation.

There is already a C-based implementation in L<Algorithm::Diff::XS>, itself drawn from
L<Algorithm::Diff::LCS>. This also cannot handle large data sets, due to the algorithm's 
requirements for large amounts of memory in these cases, and it only uses C to enhance 
parts of the L<Algorithm::Diff> API. By contrast, this module uses the underlying C code 
across the whole of the L<Algorithm::Diff> API. 

=head1 DIFFERENCES FROM L<Algorithm::Diff>

The principal difference is internal, and should generally not matter to module users. This
module uses a different algorithm - essentially the same algorithm used by GNU diff. 

All the tests for L<Algorithm::Diff> have been included and are applied, in a slightly 
updated form. 

The prepare function is defined, but has no significant performance advantage unless
you have a particularly slow key generation function. 

=head1 OBJECT INTERFACE

L<Algorithm::Diff::Fast> has the same object interface as L<Algorithm::Diff>, and
indeed the code is drawn from L<Algorithm::Diff>. It uses the underlying diff engine
as L<Algorithm::Diff::Fast>, so the performance is greater. 

=head1 FUNCTIONS

The functions compare elements using string eq. Where a function in L<Algorithm::Diff>
permits and uses a key generation function, the same function also allows a key generation
function in L<Algorithm::Diff::Fast>. 

=head2 C<LCS>

Given references to two lists of items, LCS returns an array containing
their longest common subsequence.  In scalar context, it returns a
reference to such a list.

    @lcs    = LCS( \@seq1, \@seq2 );
    $lcsref = LCS( \@seq1, \@seq2 );

C<LCS> may be passed an optional third parameter; this is a CODE
reference to a key generation function.  See L</KEY GENERATION
FUNCTIONS>.

    @lcs    = LCS( \@seq1, \@seq2, \&keyGen, @args );
    $lcsref = LCS( \@seq1, \@seq2, \&keyGen, @args );

Additional parameters, if any, will be passed to the key generation
routine.

=head2 C<LCSidx>

Like C<LCS> except it returns references to two arrays.  The first array
contains the indices into @seq1 where the LCS items are located.  The
second array contains the indices into @seq2 where the LCS items are located.

Therefore, the following three lists will contain the same values:

    my( $idx1, $idx2 ) = LCSidx( \@seq1, \@seq2 );
    my @list1 = @seq1[ @$idx1 ];
    my @list2 = @seq2[ @$idx2 ];
    my @list3 = LCS( \@seq1, \@seq2 );

=head2 C<LCS_length>

This is just like C<LCS> except it only returns the length of the
longest common subsequence.  This may provide a small performance gain 
compared to C<LCS>.

=head2 C<compact_diff>

C<compact_diff> is much like C<sdiff> except it returns a much more
compact description consisting of just one flat list of indices.  An
example helps explain the format:

    my @a = qw( a b c   e  h j   l m n p      );
    my @b = qw(   b c d e f  j k l m    r s t );
    @cdiff = compact_diff( \@a, \@b );
    # Returns:
    #   @a      @b       @a       @b
    #  start   start   values   values
    (    0,      0,   #       =
         0,      0,   #    a  !
         1,      0,   #  b c  =  b c
         3,      2,   #       !  d
         3,      3,   #    e  =  e
         4,      4,   #    f  !  h
         5,      5,   #    j  =  j
         6,      6,   #       !  k
         6,      7,   #  l m  =  l m
         8,      9,   #  n p  !  r s t
        10,     12,   #
    );

The 0th, 2nd, 4th, etc. entries are all indices into @seq1 (@a in the
above example) indicating where a hunk begins.  The 1st, 3rd, 5th, etc.
entries are all indices into @seq2 (@b in the above example) indicating
where the same hunk begins.

So each pair of indices (except the last pair) describes where a hunk
begins (in each sequence).  Since each hunk must end at the item just
before the item that starts the next hunk, the next pair of indices can
be used to determine where the hunk ends.

So, the first 4 entries (0..3) describe the first hunk.  Entries 0 and 1
describe where the first hunk begins (and so are always both 0).
Entries 2 and 3 describe where the next hunk begins, so subtracting 1
from each tells us where the first hunk ends.  That is, the first hunk
contains items C<$diff[0]> through C<$diff[2] - 1> of the first sequence
and contains items C<$diff[1]> through C<$diff[3] - 1> of the second
sequence.

In other words, the first hunk consists of the following two lists of items:

               #  1st pair     2nd pair
               # of indices   of indices
    @list1 = @a[ $cdiff[0] .. $cdiff[2]-1 ];
    @list2 = @b[ $cdiff[1] .. $cdiff[3]-1 ];
               # Hunk start   Hunk end

Note that the hunks will always alternate between those that are part of
the LCS (those that contain unchanged items) and those that contain
changes.  This means that all we need to be told is whether the first
hunk is a 'same' or 'diff' hunk and we can determine which of the other
hunks contain 'same' items or 'diff' items.

By convention, we always make the first hunk contain unchanged items.
So the 1st, 3rd, 5th, etc. hunks (all odd-numbered hunks if you start
counting from 1) all contain unchanged items.  And the 2nd, 4th, 6th,
etc. hunks (all even-numbered hunks if you start counting from 1) all
contain changed items.

Since @a and @b don't begin with the same value, the first hunk in our
example is empty (otherwise we'd violate the above convention).  Note
that the first 4 index values in our example are all zero.  Plug these
values into our previous code block and we get:

    @hunk1a = @a[ 0 .. 0-1 ];
    @hunk1b = @b[ 0 .. 0-1 ];

And C<0..-1> returns the empty list.

Move down one pair of indices (2..5) and we get the offset ranges for
the second hunk, which contains changed items.

Since C<@diff[2..5]> contains (0,0,1,0) in our example, the second hunk
consists of these two lists of items:

        @hunk2a = @a[ $cdiff[2] .. $cdiff[4]-1 ];
        @hunk2b = @b[ $cdiff[3] .. $cdiff[5]-1 ];
    # or
        @hunk2a = @a[ 0 .. 1-1 ];
        @hunk2b = @b[ 0 .. 0-1 ];
    # or
        @hunk2a = @a[ 0 .. 0 ];
        @hunk2b = @b[ 0 .. -1 ];
    # or
        @hunk2a = ( 'a' );
        @hunk2b = ( );

That is, we would delete item 0 ('a') from @a.

Since C<@diff[4..7]> contains (1,0,3,2) in our example, the third hunk
consists of these two lists of items:

        @hunk3a = @a[ $cdiff[4] .. $cdiff[6]-1 ];
        @hunk3a = @b[ $cdiff[5] .. $cdiff[7]-1 ];
    # or
        @hunk3a = @a[ 1 .. 3-1 ];
        @hunk3a = @b[ 0 .. 2-1 ];
    # or
        @hunk3a = @a[ 1 .. 2 ];
        @hunk3a = @b[ 0 .. 1 ];
    # or
        @hunk3a = qw( b c );
        @hunk3a = qw( b c );

Note that this third hunk contains unchanged items as our convention demands.

You can continue this process until you reach the last two indices,
which will always be the number of items in each sequence.  This is
required so that subtracting one from each will give you the indices to
the last items in each sequence.

=head2 C<traverse_sequences>

C<traverse_sequences> used to be the most general facility provided by
this module (the new OO interface is more powerful and much easier to
use).

Imagine that there are two arrows.  Arrow A points to an element of
sequence A, and arrow B points to an element of the sequence B. 
Initially, the arrows point to the first elements of the respective
sequences.  C<traverse_sequences> will advance the arrows through the
sequences one element at a time, calling an appropriate user-specified
callback function before each advance.  It willadvance the arrows in
such a way that if there are equal elements C<$A[$i]> and C<$B[$j]>
which are equal and which are part of the LCS, there will be some moment
during the execution of C<traverse_sequences> when arrow A is pointing
to C<$A[$i]> and arrow B is pointing to C<$B[$j]>.  When this happens,
C<traverse_sequences> will call the C<MATCH> callback function and then
it will advance both arrows.

Otherwise, one of the arrows is pointing to an element of its sequence
that is not part of the LCS.  C<traverse_sequences> will advance that
arrow and will call the C<DISCARD_A> or the C<DISCARD_B> callback,
depending on which arrow it advanced.  If both arrows point to elements
that are not part of the LCS, then C<traverse_sequences> will advance
one of them and call the appropriate callback, but it is not specified
which it will call.

The arguments to C<traverse_sequences> are the two sequences to
traverse, and a hash which specifies the callback functions, like this:

    traverse_sequences(
        \@seq1, \@seq2,
        {   MATCH => $callback_1,
            DISCARD_A => $callback_2,
            DISCARD_B => $callback_3,
        }
    );

Callbacks for MATCH, DISCARD_A, and DISCARD_B are invoked with at least
the indices of the two arrows as their arguments.  They are not expected
to return any values.  If a callback is omitted from the table, it is
not called.

Callbacks for A_FINISHED and B_FINISHED are invoked with at least the
corresponding index in A or B.

If arrow A reaches the end of its sequence, before arrow B does,
C<traverse_sequences> will call the C<A_FINISHED> callback when it
advances arrow B, if there is such a function; if not it will call
C<DISCARD_B> instead.  Similarly if arrow B finishes first. 
C<traverse_sequences> returns when both arrows are at the ends of their
respective sequences.  It returns true on success and false on failure. 
At present there is no way to fail.

C<traverse_sequences> may be passed an optional fourth parameter; this
is a CODE reference to a key generation function.  See L</KEY GENERATION
FUNCTIONS>.

Additional parameters, if any, will be passed to the key generation function.

If you want to pass additional parameters to your callbacks, but don't
need a custom key generation function, you can get the default by
passing undef:

    traverse_sequences(
        \@seq1, \@seq2,
        {   MATCH => $callback_1,
            DISCARD_A => $callback_2,
            DISCARD_B => $callback_3,
        },
        undef,     # default key-gen
        $myArgument1,
        $myArgument2,
        $myArgument3,
    );

C<traverse_sequences> does not have a useful return value; you are
expected to plug in the appropriate behavior with the callback
functions.

=head2 C<traverse_balanced>

C<traverse_balanced> is an alternative to C<traverse_sequences>. It
uses a different algorithm to iterate through the entries in the
computed LCS. Instead of sticking to one side and showing element changes
as insertions and deletions only, it will jump back and forth between
the two sequences and report I<changes> occurring as deletions on one
side followed immediatly by an insertion on the other side.

In addition to the C<DISCARD_A>, C<DISCARD_B>, and C<MATCH> callbacks
supported by C<traverse_sequences>, C<traverse_balanced> supports
a C<CHANGE> callback indicating that one element got C<replaced> by another:

    traverse_balanced(
        \@seq1, \@seq2,
        {   MATCH => $callback_1,
            DISCARD_A => $callback_2,
            DISCARD_B => $callback_3,
            CHANGE    => $callback_4,
        }
    );

If no C<CHANGE> callback is specified, C<traverse_balanced>
will map C<CHANGE> events to C<DISCARD_A> and C<DISCARD_B> actions,
therefore resulting in a similar behaviour as C<traverse_sequences>
with different order of events.

The C<sdiff> function of this module is implemented as call to C<traverse_balanced>.

C<traverse_balanced> does not have a useful return value; you are expected to
plug in the appropriate behavior with the callback functions.

=head1 TODO

Proper leak testing is needed. I have run the module repeatedly on large test sets,
and there is no evidence of leaking, but I would feel happier if I'd really checked
this with leak detecting tools. 

=head1 AUTHOR

Stuart Watt, stuart@morungos.com.

=head1 LICENSE

Includes portions of libmba, copyright (c) 2004 Michael B. Allen,
<mba2000@ioplex.com>, and used under the MIT license. 

Perl module code copyright (c) 2010 Stuart Watt. Perl tests and 
documentation adapted from L<Algorithm::Diff> contributors including 
Mark-Jason Dominus, Ned Konz, Mike Schilli, and Tye McQueen. 

This program is free software; you can redistribute it and/or modify it
under the MIT license.

=cut