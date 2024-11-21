[![Actions Status](https://github.com/kfly8/Result-Simple/actions/workflows/test.yml/badge.svg)](https://github.com/kfly8/Result-Simple/actions) [![Coverage Status](https://img.shields.io/coveralls/kfly8/Result-Simple/main.svg?style=flat)](https://coveralls.io/r/kfly8/Result-Simple?branch=main) [![MetaCPAN Release](https://badge.fury.io/pl/Result-Simple.svg)](https://metacpan.org/release/Result-Simple)
# NAME

Result::Simple - A dead simple perl-ish result type like Haskell, Rust, Go, etc.

# SYNOPSIS

```perl
use Test2::V0;
use Result::Simple;
use Types::Standard qw( Int Str );

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
```

# DESCRIPTION

`Result::Simple` is a dead simple perl-ish result type.

Result type is a type constraint that can represent either success or failure. This pattern is used in modern languages such as Haskell, Rust, Go, etc to handle errors and effectively manage the flow of control.

In perl, this pattern is also useful. And this module provides a simple way to use it. This module does not wrap return value in an object. Just return a tuple of `(Data, Undef)` or `(Undef, Error)`.

## EXPORT

### Ok

```
Ok($value) : ($value, undef)
```

Return a tuple of values and undef. When the function succeeds, it should return this.

### Err

```
Err($err) : (undef, $err)
```

Return a tuple of undef and error. When the function fails, it should return this.
If the error is not a trusy value, it will throw an exception.

## ATTRIBUTES

### :Result(T, E)

```perl
sub foo :Result(Int, Str) ($input) {
    Ok('hello');
}
# => throw exception: Invalid data type in `foo`: "hello"
```

This attribute is used to define a function that returns a success or failure.
Type T is the return type when the function is successful, and type E is the return type when the function fails.

Types requires `check` method that returns true or false. So you can use your favorite type constraint module like
[Type::Tiny](https://metacpan.org/pod/Type%3A%3ATiny), [Moose](https://metacpan.org/pod/Moose), [Mouse](https://metacpan.org/pod/Mouse) or [Data::Checks](https://metacpan.org/pod/Data%3A%3AChecks) etc.

If the `RESULT_SIMPLE_CHECK_ENABLED` environment variable is set to a true value, the type check will be enabled.
It means that `:Result` attribute does not do anything when the environment variable is false. It is useful for production code.

## ENVIRONMENTS

### RESULT\_SIMPLE\_CHECK\_ENABLED

If this environment variable is set to a true value, the type check will be enabled. Default is false.

# LICENSE

Copyright (C) kobaken.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

kobaken <kentafly88@gmail.com>
