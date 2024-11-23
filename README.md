[![Actions Status](https://github.com/kfly8/Result-Simple/actions/workflows/test.yml/badge.svg)](https://github.com/kfly8/Result-Simple/actions) [![Coverage Status](https://img.shields.io/coveralls/kfly8/Result-Simple/main.svg?style=flat)](https://coveralls.io/r/kfly8/Result-Simple?branch=main) [![MetaCPAN Release](https://badge.fury.io/pl/Result-Simple.svg)](https://metacpan.org/release/Result-Simple)
# NAME

Result::Simple - A dead simple perl-ish Result like F#, Rust, Go, etc.

# SYNOPSIS

```perl
# Enable type check. Default is false.
BEGIN { $ENV{RESULT_SIMPLE_CHECK_ENABLED} = 1 }

use v5.40;
use Test2::V0;

use Result::Simple;
use Types::Common -types;

use kura ErrorMessage => StrLength[3,];
use kura ValidName    => sub { my (undef, $e) = validate_name($_); !$e };
use kura ValidAge     => sub { my (undef, $e) = validate_age($_); !$e };
use kura ValidUser    => Dict[name => ValidName, age => ValidAge];

sub validate_name($name) {
    return Err('No name') unless defined $name;
    return Err('Empty name') unless length $name;
    return Err('Reserved name') if $name eq 'root';
    return Ok($name);
}

sub validate_age($age) {
    return Err('No age') unless defined $age;
    return Err('Invalid age') unless $age =~ /\A\d+\z/;
    return Err('Too young age') if $age < 18;
    return Ok($age);
}

sub new_user :Result(ValidUser, ArrayRef[ErrorMessage]) ($args) {
    my @errors;

    my ($name, $name_err) = validate_name($args->{name});
    push @errors, $name_err if $name_err;

    my ($age, $age_err) = validate_age($args->{age});
    push @errors, $age_err if $age_err;

    return Err(\@errors) if @errors;
    return Ok({ name => $name, age => $age });
}

my ($user1, $err1) = new_user({ name => 'taro', age => 42 });
is $user1, { name => 'taro', age => 42 };
is $err1, undef;

my ($user2, $err2) = new_user({ name => 'root', age => 1 });
is $user2, undef;
is $err2, ['Reserved name', 'Too young age'];
```

# DESCRIPTION

Result::Simple is a dead simple Perl-ish Result.

Result represents a function's return value as success or failure, enabling safer error handling and more effective control flow management.
This pattern is used in other languages such as F#, Rust, and Go.

In Perl, this pattern is also useful, and this module provides a simple way to use it.
This module does not wrap a return value in an object. Just return a tuple like `($data, undef)` or `(undef, $err)`.

## EXPORT FUNCTIONS

### Ok

```perl
Ok($data)
# => ($data, undef)
```

Return a tuple of value and undef. When the function succeeds, it should return this.

### Err

```perl
Err($err)
# => (undef, $err)
```

Return a tuple of undef and error. When the function fails, it should return this.
Note that the error value should not be a falsy value, otherwise it will throw an exception.

## ATTRIBUTES

### :Result(T, E)

```perl
sub foo :Result(Int, Error) ($input) {
    Ok('hello');
}
# => throw exception: Invalid success result in `foo`: ["hello", undef] (when CHECK_ENABLED is true)
# => no exception (when CHECK_ENABLED is false)
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
# Enable type check.
BEGIN {
    $ENV{RESULT_SIMPLE_CHECK_ENABLED} = 1;
}
```

# NOTE

## What happens when you forget to call `Ok` or `Err`?

The following example is a common mistake:

```perl
sub validate_name :Result(Str, ErrorMessage) ($name) {
    return "Empty name" unless $name; # Oops! forgot to call `Err` function.
    return Ok($name);
}

my ($name, $err) = validate_name('');
# => throw exception: Invalid result tuple (T, E)
```

In this case, the function throws an exception. But this is lucky case. The following case is not detected,
because the return value is a valid failure result `(undef, ErrorMessage)`:

```perl
sub foo :Result(Str, ErrorMessage) {
    return (undef, 'apple'); # Not call `Ok` or `Err` function.
}

my ($data, $err) = foo;
# => $err is 'apple'
```

# LICENSE

Copyright (C) kobaken.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

kobaken <kentafly88@gmail.com>
