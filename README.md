[![Actions Status](https://github.com/kfly8/Result-Simple/actions/workflows/test.yml/badge.svg)](https://github.com/kfly8/Result-Simple/actions) [![Coverage Status](https://img.shields.io/coveralls/kfly8/Result-Simple/main.svg?style=flat)](https://coveralls.io/r/kfly8/Result-Simple?branch=main) [![MetaCPAN Release](https://badge.fury.io/pl/Result-Simple.svg)](https://metacpan.org/release/Result-Simple)
# NAME

Result::Simple - A dead simple perl-ish result type like Haskell, Rust, Go, etc.

# SYNOPSIS

```perl
use Test2::V0;
use Result::Simple;
use Types::Common qw( Int NonEmptyStr );

sub parse :Result(Int, NonEmptyStr) {
    my $input = shift;
    if ($input =~ /\A(\d+)\z/) {
        Ok($1 + 0);
    } else {
        Err('Invalid input');
    }
}

sub half :Result(Int, NonEmptyStr) {
    my $n = shift;
    if ($n % 2 == 0) {
        Ok($n / 2);
    } else {
        Err('Not even');
    }
}

sub parse_and_quater :Result(Int, NonEmptyStr) {
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
```

# DESCRIPTION

`Result::Simple` is a dead simple perl-ish result type.

Result type represents a function's outcome as either success or failure, enabling safer error handling and more effective control flow management. This pattern is common in modern languages like Haskell, Rust, and Go.

In perl, this pattern is also useful. And this module provides a simple way to use it. This module does not wrap return value in an object. Just return a tuple of `(Data, Undef)` or `(Undef, Error)`.

## EXPORT FUNCTIONS

### Ok

```
Ok($data) : ($data, undef)
```

Return a tuple of value and undef. When the function succeeds, it should return this.

### Err

```
Err($err) : (undef, $err)
```

Return a tuple of undef and error. When the function fails, it should return this.
Note that the error value should not be a falsy value, otherwise it will throw an exception.

## ATTRIBUTES

### :Result(T, E)

```perl
sub foo :Result(Int, Error) ($input) {
    Ok('hello');
}
# => throw exception: Invalid data type in `foo`: "hello"
```

This attribute is used to define a function that returns a success or failure.
Type T is the return type when the function is successful, and type E is the return type when the function fails.

Types requires `check` method that returns true or false. So you can use your favorite type constraint module like
[Type::Tiny](https://metacpan.org/pod/Type%3A%3ATiny), [Moose](https://metacpan.org/pod/Moose), [Mouse](https://metacpan.org/pod/Mouse) or [Data::Checks](https://metacpan.org/pod/Data%3A%3AChecks) etc. And type E should not allow falsy values.

```perl
sub foo :Result(Int, Str) ($input) {
    ...
}
# => throw exception: Result E should not allow falsy values: ["0"]
```

If the `RESULT_SIMPLE_CHECK_ENABLED` environment variable is set to a true value, the type check will be enabled.
This means that `:Result` attribute does not do anything when the environment variable is false. It is useful for production code.

## ENVIRONMENTS

### `$ENV{RESULT_SIMPLE_CHECK_ENABLED}`

If this environment variable is set to a true value, the type check will be enabled. Default is false.

```
BEGIN {
    $ENV{RESULT_SIMPLE_CHECK_ENABLED} = 1;
}
```

# LICENSE

Copyright (C) kobaken.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

kobaken <kentafly88@gmail.com>
