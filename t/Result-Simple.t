=pod

Test the Result::Simple module with CHECK_ENABLED is truthy.

=cut

use Test2::V0 qw(subtest is like unlike dies note done_testing);

use lib "t/lib";
use TestType qw( Int NonEmptyStr );

BEGIN {
    # Enable type check. The default is true.
    # $ENV{RESULT_SIMPLE_CHECK_ENABLED} = 1;
}

use Result::Simple qw( ok err result_for unsafe_unwrap unsafe_unwrap_err chain pipeline );

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
        subtest 'stacktrace' => sub {
            result_for test_stacktrace => Int, NonEmptyStr;
            sub test_stacktrace { Carp::confess('hello') }

            local $@;
            eval { my ($data, $err) = test_stacktrace() };
            my $error = $@;
            my @errors = split /\n/, $error;

            my $file = __FILE__;
            my $line = __LINE__;

            like $errors[0], qr!hello at $file line @{[$line - 8]}!;
            like $errors[1], qr!test_stacktrace\(\) called at $file line @{[$line - 5]}!, 'stacktrace includes function name';
            unlike $error, qr!Result/Simple.pm!, 'stacktrace does not include Result::Simple';
            note $errors[0];
            note $errors[1];
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

        subtest 'When function is not found, then throw a exception' => sub {
            like dies { result_for xxx => Int, NonEmptyStr } => qr/result_for: function `xxx` not found/;
        };
    };
};

subtest 'Test `unsafe_unwrap` function' => sub {
    subtest 'When ok() is called, then return the value' => sub {
        my $got = unsafe_unwrap(ok(42));
        is $got, 42;
    };

    subtest 'When err() is called, then throw a exception' => sub {
        like dies { my ($data, $err) = unsafe_unwrap(err('foo')) }, qr/Error called in `unsafe_unwrap`/;
    };
};

subtest 'Test `unsafe_unwrap_err` function' => sub {
    subtest 'When ok() is called, then throw a exception' => sub {
        like dies { my ($data, $err) = unsafe_unwrap_err(ok(42)) }, qr/No error called in `unsafe_unwrap_err`/;
    };
    subtest 'When err() is called, then return the value' => sub {
        my $got = unsafe_unwrap_err(err('foo'));
        is $got, 'foo';
    };
};

subtest 'Test `chain` function' => sub {
    sub chain_test {
        my $v = shift;
        return err('No more') if $v == 1;
        return ok($v / 2);
    }

    my ($v1, $e1) = chain(chain_test => ok(8));
    is $v1, 4;
    is $e1, undef;

    my ($v2, $e2) = chain(chain_test => ok(1));
    is $v2, undef;
    is $e2, 'No more';

    my ($v3, $e3) = chain(chain_test => err('foo'));
    is $v3, undef;
    is $e3, 'foo';

    like dies { my $v = chain(chain_test => 1, 2) }, qr/`chain` must be called in list context/;
    like dies { my ($v, $e) = chain(chain_test => 1) }, qr/`chain` arguments must be func and result/;
    like dies { my ($v, $e) = chain(unknown => 1, 2) }, qr/Function `unknown` not found in main/;

    subtest 'stacktrace' => sub {
        sub chain_stacktrace { Carp::confess('hello') }

        local $@;
        eval { my ($v, $e) = chain(chain_stacktrace => ok(8)) };
        my $error = $@;
        my @errors = split /\n/, $error;

        my $file = __FILE__;
        my $line = __LINE__;

        like $errors[0], qr!hello at $file line @{[$line - 8]}!, 'Throw an exception at `chain_stacktrace` function';
        like $errors[1], qr!chain_stacktrace\(8\) called at .+/Result/Simple.pm!;
        like $errors[2], qr!chain\("chain_stacktrace", 8, undef\) called at $file line @{[$line - 5]}!;

        note $errors[0];
        note $errors[1];
        note $errors[2];
    }
};

subtest 'Test `pipeline` function' => sub {
    sub pipeline_test {
        my $v = shift;
        return err('No more') if $v == 1;
        return ok($v / 2);
    }

    my $code = pipeline qw( pipeline_test pipeline_test );
    my ($v1, $e1) = $code->(ok(8));
    is $v1, 2;
    is $e1, undef;

    my ($v2, $e2) = $code->(ok(2));
    is $v2, undef;
    is $e2, 'No more';

    my ($v3, $e3) = $code->(ok(1));
    is $v3, undef;
    is $e3, 'No more';

    like dies { my $v = $code->(1, 2) }, qr/pipelined function must be called in list context/;
    like dies { my ($v, $e) = $code->(1) }, qr/pipelined function arguments must be result/;
    like dies { my $c = pipeline qw( unknown ) }, qr/Function `unknown` not found in main/;

    subtest 'stacktrace' => sub {
        sub pipeline_stacktrace { Carp::confess('hello') }

        my $pipelined = pipeline qw( pipeline_test pipeline_stacktrace );

        local $@;
        eval { my ($v, $e) = $pipelined->(ok(8)) };
        my $error = $@;
        my @errors = split /\n/, $error;

        my $file = __FILE__;
        my $line = __LINE__;

        like $errors[0], qr!hello at $file line @{[$line - 10]}!, 'Throw an exception at `pline_stacktrace` function';
        like $errors[1], qr!pipeline_stacktrace\(4\) called!;
        like $errors[2], qr!__PIPELINED_FUNCTION__\(8, undef\) called at $file line @{[$line - 5]}!;
        note $errors[0];
        note $errors[1];
        note $errors[2];
    }
};

done_testing;
