=pod

Test the Result::Simple module with CHECK_ENABLED is truthy.

=cut

use Test2::V0 qw(subtest is like unlike dies done_testing);

use lib "t/lib";
use TestType qw( Int NonEmptyStr );

BEGIN {
    # Enable type check. The default is true.
    # $ENV{RESULT_SIMPLE_CHECK_ENABLED} = 1;
}

use Result::Simple qw( ok err result_for );

subtest 'Test `ok` and `err` functions' => sub {
    subtest '`ok` and `err` functions just return values' => sub {
        my ($data, $err) = ok('foo');
        is $data, 'foo';
        is $err, undef;

        ($data, $err) = err('bar');
        is $data, undef;
        is $err, 'bar';
    };

    subtest '`ok` and `err` must be called in list context' => sub {
        like dies { my $data = ok('foo') }, qr/`ok` must be called in list context/;
        like dies { my $err = err('bar') }, qr/`err` must be called in list context/;
    };

    subtest '`ok` and `err` does not allow multiple arguments' => sub {
        like dies { my ($data, $err) = ok('foo', 'bar') }, qr/`ok` does not allow multiple arguments/;
        like dies { my ($data, $err) = err('bar', 'foo') }, qr/`err` does not allow multiple arguments/;
    };

    subtest '`ok` and `err` does not allow no arguments' => sub {
        like dies { my ($data, $err) = ok() }, qr/`ok` does not allow no arguments/;
        like dies { my ($data, $err) = err() }, qr/`err` does not allow no arguments/;
    };

    subtest '`err` does not allow falsy values' => sub {
        like dies { my ($data, $err) = err(0) }, qr/`err` does not allow a falsy value: 0/;
        like dies { my ($data, $err) = err('0') }, qr/`err` does not allow a falsy value: '0'/;
        like dies { my ($data, $err) = err('') }, qr/`err` does not allow a falsy value: ''/;
    };
};

subtest 'Test `result_for` function' => sub {
    # valid cases
    result_for valid => Int, NonEmptyStr;
    sub valid { ok(42) }

    result_for no_error => Int, undef;
    sub no_error { ok(42) }

    # invalid cases
    result_for invalid_ok_type => Int, NonEmptyStr;
    sub invalid_ok_type { ok('foo') }

    result_for invalid_err_type => Int, NonEmptyStr;
    sub invalid_err_type { err(\1) }

    result_for a_few_result => Int, NonEmptyStr;
    sub a_few_result { 'foo' }

    result_for too_many_result => Int, NonEmptyStr;
    sub too_many_result { (1,2,3) }

    result_for never_return_error => Int, undef;
    sub never_return_error { err('foo') }

    subtest 'When a return value satisfies the Result type (T, E), then return the value' => sub {
        my ($data, $err) = valid();
        is $data, 42;
        is $err, undef;
    };

    subtest 'When a return value satisfies the Result type (T, undef), then return the value' => sub {
        my ($data, $err) = no_error();
        is $data, 42;
        is $err, undef;
    };

    subtest 'When a return value does not satisfy the Result type (T, E), then throw a exception' => sub {
        like dies { my ($data, $err) = invalid_ok_type() },    qr!Invalid success result in `invalid_ok_type`: \['foo',undef\]!;
        like dies { my ($data, $err) = invalid_err_type() },   qr!Invalid failure result in `invalid_err_type`: \[undef,\\1\]!;
        like dies { my ($data, $err) = a_few_result() },       qr!Invalid result tuple \(T, E\) in `a_few_result`. Do you forget to call `ok` or `err` function\? Got: \['foo'\]!;
        like dies { my ($data, $err) = too_many_result() },    qr!Invalid result tuple \(T, E\) in `too_many_result`. Do you forget to call `ok` or `err` function\? Got: \[1,2,3\]!;
        like dies { my ($data, $err) = never_return_error() }, qr!Never return error in `never_return_error`: \[undef,'foo'\]!;
    };

    subtest 'Must handle error' => sub {
        like dies { my $result = valid() }, qr/Must handle error in `valid`/;
    };

    subtest '(T, E) requires `check` method' => sub {
        sub invalid_type_T { ok(42) };
        like dies { result_for invalid_type_T => 'Hello', NonEmptyStr }, qr!result_for T requires `check` method!;

        sub invalid_type_E { err(42) };
        like dies { result_for invalid_type_E => Int, 'World' }, qr!result_for E requires `check` method!;
    };

    subtest 'E should not allow falsy values' => sub {
        sub should_not_allow_falsy { err(0) };
        like dies { result_for should_not_allow_falsy => Int, Int }, qr/result_for E should not allow falsy values: \[0,'0'\]/;
    };

    subtest 'Test the details of `retsult_for` function' => sub {
        subtest 'Useful stacktrace' => sub {

            result_for test_stacktrace => Int, NonEmptyStr;
            sub test_stacktrace { Carp::confess('hello') }

            eval { my ($data, $err) = test_stacktrace() };

            my $file = __FILE__;
            like $@, qr!hello at $file line!;
            like $@, qr/main::test_stacktrace\(\) called at $file line /, 'stacktrace includes function name';
            unlike $@, qr/Result::Simple::/, 'stacktrace does not include Result::Simple by Scope::Upper';
        };

        subtest 'Same subname and prototype as original' => sub {

            result_for same => Int, NonEmptyStr;
            sub same (;$) { ok(42) }

            my $code = \&same;

            require Sub::Util;
            my $name = Sub::Util::subname($code);
            is $name, 'main::same';

            my $proto = Sub::Util::prototype($code);
            is $proto, ';$';
        };
    };
};

done_testing;
