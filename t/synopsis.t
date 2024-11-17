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
    my ($ok, $result) = parse(@_);
    return Err($result) unless $ok;

    ($ok, $result) = half($result);
    return Err($result) unless $ok;

    half($result);
}

my ($ok, $result) = parse_and_quater('84');
ok $ok;
is $result, 21;

($ok, $result) = parse_and_quater('hello');
ok !$ok;
is $result, 'Invalid input';

($ok, $result) = parse_and_quater('42');
ok !$ok;
is $result, 'Not even';

done_testing
