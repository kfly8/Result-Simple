use strict;
use warnings;
use Test::More;

use lib "t/lib";
use TestType qw( Int Str );

BEGIN {
    $ENV{RESULT_SIMPLE_CHECK_ENABLED} = 1;
}

use Result::Simple;

subtest 'Test `Ok` and `Err` functions' => sub {
    subtest '`Ok` and `Err` functions just return values' => sub {
        my ($data, $err) = Ok('foo');
        is $data, 'foo';
        is $err, undef;

        ($data, $err) = Err('bar');
        is $data, undef;
        is $err, 'bar';
    };

    subtest '`Ok` and `Err` must be called in list context' => sub {
        eval { my $data = Ok('foo') };
        like $@, qr/`Ok` must be called in list context/;

        eval { my $err = Err('bar') };
        like $@, qr/`Err` must be called in list context/;
    };

    subtest '`Err` requires trusy value' => sub {
        eval { my ($data, $err) = Err() };
        like $@, qr/Err requires at least trusy value, got: undef/;

        eval { my ($data, $err) = Err(0) };
        like $@, qr/Err requires at least trusy value, got: 0/;

        eval { my ($data, $err) = Err('') };
        like $@, qr/Err requires at least trusy value, got: ""/;
    };
};

subtest 'Test :Result attribute' => sub {
    sub valid : Result(Int, Str) { Ok(42) }
    sub invalid_ok_type :Result(Int, Str) { Ok('foo') }
    sub invalid_err_type :Result(Int, Str) { Err(\1) }

    subtest 'When return value satisfies the Result type (T, E), then return the value' => sub {
        my ($data, $err) = valid();
        is $data, 42;
        is $err, undef;
    };

    subtest 'When return value does not satisfy the Result type (T, E), then throw a exception' => sub {
        eval { my ($data, $err) = invalid_ok_type() };
        like $@, qr!Invalid data type in `invalid_ok_type`: "foo"!;

        eval { my ($data, $err) = invalid_err_type() };
        like $@, qr!Invalid error type in `invalid_err_type`: \\1!;
    };

    subtest 'Must handle error' => sub {
        eval { my $result = valid() };
        like $@, qr/Must handle error in `valid`/;
    };

    subtest 'Result(T, E) requires `check` method' => sub {
        eval "sub invalid_type_T :Result('HELLO', Str) { Ok('HELLO') }";
        like $@, qr/Result T requires `check` method/;

        eval "sub invalid_type_E :Result(Int, 'WORLD') { Err('WORLD') }";
        like $@, qr/Result E requires `check` method/;
    };
};

subtest 'Test the details of :Result attribute' => sub {
    subtest 'Useful stacktrace' => sub {
        sub test_stacktrace :Result(Int, Str) { Carp::confess('hello') }

        eval { my ($data, $err) = test_stacktrace() };

        my $file = __FILE__;
        like $@, qr!hello at $file line!;
        like $@, qr/main::test_stacktrace\(\) called at $file line /, 'stacktrace includes function name';
        unlike $@, qr/Result::Simple::/, 'stacktrace does not include Result::Simple by Scope::Upper';
    };

    subtest 'Same subname and prototype as original' => sub {
        sub same (;$) :Result(Int, Str) { Ok(42) }

        my $code = \&same;

        require Sub::Util;
        my $name = Sub::Util::subname($code);
        is $name, 'main::same';

        my $proto = Sub::Util::prototype($code);
        is $proto, ';$';
    };
};

done_testing;
