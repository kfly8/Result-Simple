[![Actions Status](https://github.com/kfly8/Result-Simple/actions/workflows/test.yml/badge.svg)](https://github.com/kfly8/Result-Simple/actions) [![Coverage Status](https://img.shields.io/coveralls/kfly8/Result-Simple/main.svg?style=flat)](https://coveralls.io/r/kfly8/Result-Simple?branch=main) [![MetaCPAN Release](https://badge.fury.io/pl/Result-Simple.svg)](https://metacpan.org/release/Result-Simple)
# NAME

Result::Simple - A dead simple perl-ish Result like F#, Rust, Go, etc.

# SYNOPSIS

```perl
use Result::Simple qw( ok err result_for );
use Types::Standard -types;

use kura Error   => Dict[message => Str];
use kura Request => Dict[name => Str, age => Int];

result_for validate_name => Request, Error;

sub validate_name {
    my $req = shift;
    my $name = $req->{name};
    return err({ message => 'No name'}) unless defined $name;
    return err({ message => 'Empty name'}) unless length $name;
    return err({ message => 'Reserved name'}) if $name eq 'root';
    return ok($req);
}

result_for validate_age => Request, Error;

sub validate_age {
    my $req = shift;
    my $age = $req->{age};
    return err({ message => 'No age'}) unless defined $age;
    return err({ message => 'Invalid age'}) unless $age =~ /\A\d+\z/;
    return err({ message => 'Too young age'}) if $age < 18;
    return ok($req);
}

result_for validate_req => Request, Error;

sub validate_req {
    my $req = shift;
    my $err;

    # $req = validate_name($req); # => Throw error! It requires list context to handle error
    ($req, $err) = validate_name($req);
    return err($err) if $err;

    ($req, $err) = validate_age($req);
    return err($err) if $err;

    return ok($req);
}

my ($req1, $err1) = validate_req({ name => 'taro', age => 42 });
$req1 # => { name => 'taro', age => 42 };
$err1 # => undef;

my ($req2, $err2) = validate_req({ name => 'root', age => 20 });
$req2 # => undef;
$err2 # => { message => 'Reserved name' };
```

# DESCRIPTION

Result::Simple is a dead simple Perl-ish Result.

Result represents a function's return value as success or failure, enabling safer error handling and more effective control flow management.
This pattern is used in other languages such as F#, Rust, and Go.

In Perl, this pattern is also useful, and this module provides a simple way to use it.
This module does not wrap a return value in an object. Just return a tuple like `($data, undef)` or `(undef, $err)`.

## EXPORT FUNCTIONS

### ok($value)

Return a tuple of a given value and undef. When the function succeeds, it should return this.

```perl
sub add($a, $b) {
    ok($a + $b); # => ($a + $b, undef)
}
```

### err($error)

Return a tuple of undef and a given error. When the function fails, it should return this.

```perl
sub div($a, $b) {
    return err('Division by zero') if $b == 0; # => (undef, 'Division by zero')
    ok($a / $b);
}
```

Note that the error value must be a truthy value, otherwise it will throw an exception.

### result\_for $function\_name => $T, $E

You can use the `result_for` to define a function that returns a success or failure and asserts the return value types. Here is an example:

```perl
result_for half => Int, ErrorMessage;

sub half ($n) {
    if ($n % 2) {
        return err('Odd number');
    } else {
        return ok($n / 2);
    }
}
```

- T (success type)

    When the function succeeds, then returns `($data, undef)`, and `$data` should satisfy this type.

- E (error type)

    When the function fails, then returns `(undef, $err)`, and `$err` should satisfy this type.
    Additionally, type E must be truthy value to distinguish between success and failure.

    ```perl
    result_for foo => Int, Str;

    sub foo ($input) { }
    # => throw exception: Result E should not allow falsy values: ["0"] because Str allows "0"
    ```

    When a function never returns an error, you can set type E to `undef`:

    ```perl
    result_for bar => Int, undef;
    sub double ($n) { ok($n * 2) }
    ```

### unsafe\_unwrap($data, $err)

`unsafe_unwrap` takes a Result<T, E> and returns a T when the result is an Ok, otherwise it throws exception.
It should be used in tests or debugging code.

### unsafe\_unwrap\_err($data, $err)

`unsafe_unwrap_err` takes a Result<T, E> and returns an E when the result is an Err, otherwise it throws exception.
It should be used in tests or debugging code.

Note that types require `check` method that returns true or false. So you can use your favorite type constraint module like
[Type::Tiny](https://metacpan.org/pod/Type%3A%3ATiny), [Moose](https://metacpan.org/pod/Moose), [Mouse](https://metacpan.org/pod/Mouse) or [Data::Checks](https://metacpan.org/pod/Data%3A%3AChecks) etc.

## ENVIRONMENTS

### `$ENV{RESULT_SIMPLE_CHECK_ENABLED}`

If the `ENV{RESULT_SIMPLE_CHECK_ENABLED}` environment is truthy before loading this module, it works as an assertion.
Otherwise, if it is falsy, `result_for` attribute does nothing. The default is true.
This option is useful for development and testing mode, and it recommended to set it to false for production.

```perl
result_for foo => Int, undef;
sub foo { ok("hello") }

my ($data, $err) = foo();
# => throw exception when check enabled
```

# NOTE

## Avoiding Ambiguity in Result Handling

Forgetting to call `ok` or `err` function is a common mistake. Consider the following example:

```perl
result_for validate_name => Str, ErrorMessage;

sub validate_name ($name) {
    return "Empty name" unless $name; # Oops! Forgot to call `err` function.
    return ok($name);
}

my ($name, $err) = validate_name('');
# => throw exception: Invalid result tuple (T, E)
```

In this case, the function throws an exception because the return value is not a valid result tuple `($data, undef)` or `(undef, $err)`.
This is fortunate, as the mistake is detected immediately. The following case is not detected:

```perl
result_for foo => Str, ErrorMessage;

sub foo {
    return (undef, 'apple'); # No use of `ok` or `err` function.
}

my ($data, $err) = foo;
# => $err is 'apple'
```

Here, the function returns a valid failure tuple `(undef, $err)`. However, it is unclear whether this was intentional or a mistake.
The lack of `ok` or `err` makes the intent ambiguous.

Conclusively, be sure to use `ok` or `err` functions to make it clear whether the success or failure is intentional.

## Use alias name

You can use alias name for `ok` and `err` functions like this:

```perl
use Result::Simple
    ok => { -as => 'left' },
    err => { -as => 'right' };

left('foo'); # => ('foo', undef)
right('bar'); # => (undef, 'bar')
```

# LICENSE

Copyright (C) kobaken.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

kobaken <kentafly88@gmail.com>
