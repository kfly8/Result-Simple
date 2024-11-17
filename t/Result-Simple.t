use strict;
use warnings;
use Test::More;

use lib "t/lib";
use TestType qw( Int Str );

BEGIN {
    $ENV{RESULT_SIMPLE_CHECK_ENABLED} = 1;
}

use Result::Simple;

subtest '`Ok` function returns true and given value' => sub {
    my ($ok, $result) = Ok('foo');
    ok $ok, 'Ok returns true';
    is $result, 'foo';
};

subtest '`Err` function returns false and given value' => sub {
    my ($ok, $result) = Err('bar');
    ok !$ok, 'Err returns false';
    is $result, 'bar';
};

sub valid : Result(Int, Str) { Ok(42) }
sub invalid_ok_type :Result(Int, Str) { Ok('foo') }
sub invalid_err_type :Result(Int, Str) { Err({ foo => 1 }) }

subtest '`Result` attribute checks the return value' => sub {
    eval { my ($ok, $result) = valid() };
    ok !$@, 'No exception is thrown';

    eval { my ($ok, $result) = invalid_ok_type() };
    like $@, qr!Invalid data type in invalid_ok_type: "foo"!;

    eval { my ($ok, $result) = invalid_err_type() };
    like $@, qr!Invalid error type in invalid_err_type: \{"foo" => 1\}!;
};

subtest 'Context must be a list context' => sub {
    eval { my $result = valid() };
    like $@, qr/Must be called in list context/, ':Result enforces a list context';

    my $foo = sub { my $a = Ok('foo') };
    eval { $foo->() };
    like $@, qr/Must be called in list context/, 'Ok enforces a list context';

    my $bar = sub { my $a = Err('bar') };
    eval { $bar->() };
    like $@, qr/Must be called in list context/, 'Err enforces a list context';
};

sub test_stacktrace :Result(Int, Str) {
    Carp::confess('hello');
}

subtest 'Test stacktrace' => sub {
    eval { my ($ok, $result) = test_stacktrace() };

    my $file = __FILE__;
    like $@, qr!hello at $file line!;
    like $@, qr/main::test_stacktrace\(\) called at $file line /, 'Stacktrace includes function name';
    unlike $@, qr/Result::Simple::/, 'Stacktrace does not include Result::Simple by Scope::Upper';
};

done_testing;
