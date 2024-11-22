[![Actions Status](https://github.com/kfly8/Result-Simple/actions/workflows/test.yml/badge.svg)](https://github.com/kfly8/Result-Simple/actions) [![Coverage Status](https://img.shields.io/coveralls/kfly8/Result-Simple/main.svg?style=flat)](https://coveralls.io/r/kfly8/Result-Simple?branch=main) [![MetaCPAN Release](https://badge.fury.io/pl/Result-Simple.svg)](https://metacpan.org/release/Result-Simple)
# NAME

Result::Simple - A dead simple perl-ish Result like F#, Rust, Go, etc.

# SYNOPSIS

```perl
use Result::Simple;
use Types::Common -types;

use constant ErrorMessage => NonEmptyStr;
use constant ValidUser => Dict[name => Str, age => Int];

sub validate_name {
    my $name = shift;
    return Err('No name') unless defined $name;
    return Err('Empty name') unless length $name;
    return Err('Reserved name') if $name eq 'root';
    return Ok($name);
}

sub validate_age {
    my $age = shift;
    return Err('No age') unless defined $age;
    return Err('Invalid age') unless $age =~ /\A\d+\z/;
    return Err('Too young') if $age < 18;
    return Ok($age);
}

sub new_user :Result(ValidUser, ArrayRef[ErrorMessage]) {
    my $args = shift;
    my @errors;

    my ($name, $name_err) = validate_name($args->{name});
    push @errors, $name_err if $name_err;

    my ($age, $age_err) = validate_age($args->{age});
    push @errors, $age_err if $age_err;

    return Err(\@errors) if @errors;
    return Ok({ name => $name, age => $age });
}

my ($user1, $err1) = new_user({ name => 'taro', age => 42 });
$user1 # => { name => 'taro', age => 42 };
$err1  # => undef;

my ($user2, $err2) = new_user({ name => 'root', age => 1 });
$user2 # => undef;
$err2  # => ['Reserved name', 'Too young'];
```

# DESCRIPTION

Result::Simple is a dead simple perl-ish Result.

Result represents a function's outcome as either success or failure, enabling safer error handling and more effective control flow management. This pattern is used in other languages such as F#, Rust, and Go.

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
# => throw exception: Invalid data type in `foo`: "hello" (when CHECK_ENABLED is true)
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
