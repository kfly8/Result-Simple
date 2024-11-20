[![Actions Status](https://github.com/kfly8/Result-Simple/actions/workflows/test.yml/badge.svg)](https://github.com/kfly8/Result-Simple/actions) [![Coverage Status](https://img.shields.io/coveralls/kfly8/Result-Simple/main.svg?style=flat)](https://coveralls.io/r/kfly8/Result-Simple?branch=main) [![MetaCPAN Release](https://badge.fury.io/pl/Result-Simple.svg)](https://metacpan.org/release/Result-Simple)
# NAME

Result::Simple - dead simple perl-ish result type

# SYNOPSIS

```perl
use v5.40;
use Result::Simple;
use Types::Standard qw( Int Str );

sub parse :Result(Int, Str) ($input) {
    if ($input =~ /\A(\d+)\z/) {
        Ok($1 + 0);
    } else {
        Err('Invalid input');
    }
}

sub half :Result(Int, Str) ($n) {
    if ($n % 2 == 0) {
        Ok($n / 2);
    } else {
        Err('Not even');
    }
}

sub parse_and_quater :Result(Int, Str) ($input) {
    my ($ok, $parsed) = parse($input);
    return Err($parsed) unless $ok;

    ($ok, $result) = half($parsed);
    return Err($result) unless $ok;

    half($result);
}

my ($ok, $result) = parse_and_quater('hello');
$ok; # false
$result; # 'Invalid input'

($ok, $result) = parse_and_quater('42');
$ok; # false
$result; # 'Not even'

($ok, $result) = parse_and_quater('84');
$ok; # true
$result; # 21
```

# DESCRIPTION

This module provides a simple way to define functions that return a result type. This data type is similar to Go, Rust's Result type.

## EXPORT

### Ok

```
Ok(@values) : ($ok, @values)
```

Return a tuple of true and values. When the function is successful, it should return this.
Can be used in list context:

```perl
my $a = Ok(42); # dies with "Must be called in list context"
```

### Err

```
Err(@values) : ($ok, @values)
```

Return a tuple of false and values. When the function fails, it should return this.
Can be used in list context:

```perl
my $a = Err('error'); # dies with "Must be called in list context"
```

## ATTRIBUTES

### :Result(T, E)

```perl
sub foo :Result(Int, Str) ($input) {
    ...
}
```

This attribute is used to define a function that returns a result type.
Type T is the return type when the function is successful, and type E is the return type when the function fails.
Types requires `check` method that returns true or false. So you can use [Types::Standard](https://metacpan.org/pod/Types%3A%3AStandard) or [Data::Checks](https://metacpan.org/pod/Data%3A%3AChecks) etc.

If the `RESULT_SIMPLE_CHECK_ENABLED` environment variable is set to a true value, the type check will be enabled.

## ENVIRONMENTS

### RESULT\_SIMPLE\_CHECK\_ENABLED

If this environment variable is set to a true value, the type check will be enabled. Default is false.

# LICENSE

Copyright (C) kobaken.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

kobaken <kentafly88@gmail.com>
