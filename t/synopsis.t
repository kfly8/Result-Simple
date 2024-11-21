use strict;
use warnings;
use Test::More;

use lib "t/lib";
use TestType qw( Int Str );

use Result::Simple;

sub parse :Result(Int, Str) {
    my $input = shift;
    if ($input =~ /\A(\d+)\z/) {
        Ok($1 + 0);
    } else {
        Err('Invalid input');
    }
}

sub half :Result(Int, Str) {
    my $n = shift;
    if ($n % 2 == 0) {
        Ok($n / 2);
    } else {
        Err('Not even');
    }
}

sub parse_and_quater :Result(Int, Str) {
    my $err;
    (my $parsed, $err) = parse(@_);
    return Err($err) if $err;

    (my $halved, $err) = half($parsed);
    return Err($err) if $err;

    half($halved);
}

my ($data, $err) = parse_and_quater('84');
is $data, 21;
is $err, undef;

($data, $err) = parse_and_quater('hello');
is $data, undef;
is $err, 'Invalid input';

($data, $err) = parse_and_quater('42');
is $data, undef;
is $err, 'Not even';

done_testing
