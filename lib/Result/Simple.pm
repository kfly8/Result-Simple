package Result::Simple;
use strict;
use warnings;

our $VERSION = "0.03";

use Exporter::Shiny qw(
    ok
    err
    result_for
    unsafe_unwrap
    unsafe_unwrap_err
);

use Carp;
use Scope::Upper ();
use Sub::Util ();
use Scalar::Util ();

# If this option is true, then check `ok` and `err` functions usage and check a return value type.
# However, it should be falsy for production code, because of performance, and it is an assertion, not a validation.
use constant CHECK_ENABLED => $ENV{RESULT_SIMPLE_CHECK_ENABLED} // 1;

# err does not allow these values.
use constant FALSY_VALUES => [0, '0', '', undef];

# When the function is successful, it should return this.
sub ok {
    if (CHECK_ENABLED) {
        croak "`ok` must be called in list context" unless wantarray;
        croak "`ok` does not allow multiple arguments" if @_ > 1;
        croak "`ok` does not allow no arguments" if @_ == 0;
    }
    ($_[0], undef)
}

# When the function fails, it should return this.
sub err {
    if (CHECK_ENABLED) {
        croak "`err` must be called in list context" unless wantarray;
        croak "`err` does not allow multiple arguments." if @_ > 1;
        croak "`err` does not allow no arguments" if @_ == 0;
        croak "`err` does not allow a falsy value: @{[ _ddf($_[0]) ]}" unless $_[0];
    }
    (undef, $_[0])
}

# result_for foo => (T, E);
# This is used to define a function that returns a success or failure.
#
# Example
#
#   result_for div => Int, ErrorMessage;
#
#   sub div {
#     my ($a, $b) = @_;
#     if ($b == 0) {
#       return err('Division by zero');
#     }
#     return ok($a / $b);
#   }
sub result_for {
    unless (CHECK_ENABLED) {
        # This is a no-op if CHECK_ENABLED is false.
        return;
    }

    my ($function_name, $T, $E, %opts) = @_;

    my @caller   = caller($opts{caller_level} || 0);
    my $package  = $opts{package} || $caller[0];
    my $filename = $caller[1];
    my $line     = $caller[2];

    my $code = $package->can($function_name);

    unless ($code) {
        croak "result_for: function `$function_name` not found in package `$package` at $filename line $line\n";
    }

    unless (Scalar::Util::blessed($T) && $T->can('check')) {
        croak "result_for T requires `check` method, got: @{[ _ddf($T) ]} at $filename line $line\n";
    }

    if (defined $E) {
        unless (Scalar::Util::blessed($E) && $E->can('check')) {
            croak "result_for E requires `check` method, got: @{[ _ddf($E) ]} at $filename line $line\n";
        }

        if (my @f = grep { $E->check($_) } @{ FALSY_VALUES() }) {
            croak "result_for E should not allow falsy values: @{[ _ddf(\@f) ]} at $filename line $line\n";
        }
    }

    wrap_code($code, $package, $function_name, $T, $E);
}

# Wrap the original coderef with type check.
sub wrap_code {
    my ($code, $package, $name, $T, $E) = @_;

    my $wrapped = sub {
        croak "Must handle error in `$name`" unless wantarray;

        my @result = &Scope::Upper::uplevel($code, @_, &Scope::Upper::CALLER(0));
        unless (@result == 2) {
            Carp::confess "Invalid result tuple (T, E) in `$name`. Do you forget to call `ok` or `err` function? Got: @{[ _ddf(\@result) ]}";
        }

        my ($data, $err) = @result;

        if ($err) {
            if (defined $E) {
                if (!$E->check($err) || defined $data) {
                    Carp::confess "Invalid failure result in `$name`: @{[ _ddf([$data, $err]) ]}";
                }
            } else {
                # Result(T, undef) should not return an error.
                Carp::confess "Never return error in `$name`: @{[ _ddf([$data, $err]) ]}";
            }
        } else {
            if (!$T->check($data) || defined $err) {
                Carp::confess "Invalid success result in `$name`: @{[ _ddf([$data, $err]) ]}";
            }
        }

        ($data, $err);
    };

    my $fullname = "$package\::$name";
    Sub::Util::set_subname($fullname, $wrapped);

    my $prototype = Sub::Util::prototype($code);
    if (defined $prototype) {
        Sub::Util::set_prototype($prototype, $wrapped);
    }

    no strict qw(refs);
    no warnings qw(redefine);
    *{$fullname} = $wrapped;
}

# `unsafe_nwrap` takes a Result<T, E> and returns a T when the result is an Ok, otherwise it throws exception.
# It should be used in tests or debugging code.
sub unsafe_unwrap {
    my ($value, $err) = @_;
    if ($err) {
        croak "Error called in `unsafe_unwrap`: @{[ _ddf($err) ]}"
    }
    return $value;
}

# `unsafe_unwrap_err` takes a Result<T, E> and returns an E when the result is an Err, otherwise it throws exception.
# It should be used in tests or debugging code.
sub unsafe_unwrap_err {
    my ($value, $err) = @_;
    if (!$err) {
        croak "No error called in `unsafe_unwrap_err`: @{[ _ddf($value) ]}"
    }
    return $err;
}

# Dump data for debugging.
sub _ddf {
    my $v = shift;

    no warnings 'once';
    require Data::Dumper;
    local $Data::Dumper::Indent   = 0;
    local $Data::Dumper::Useqq    = 0;
    local $Data::Dumper::Terse    = 1;
    local $Data::Dumper::Sortkeys = 1;
    local $Data::Dumper::Maxdepth = 2;
    Data::Dumper::Dumper($v);
}

1;
__END__

=encoding utf-8

=head1 NAME

Result::Simple - A dead simple perl-ish Result like F#, Rust, Go, etc.

=head1 SYNOPSIS

    use Test2::V0;
    use Result::Simple qw(ok err result_for);
    use Types::Common -types;

    use kura ErrorMessage => StrLength[3,];
    use kura ValidName    => sub { my (undef, $e) = validate_name($_); !$e };
    use kura ValidAge     => sub { my (undef, $e) = validate_age($_); !$e };
    use kura ValidUser    => Dict[name => ValidName, age => ValidAge];

    sub validate_name {
        my $name = shift;
        return err('No name') unless defined $name;
        return err('Empty name') unless length $name;
        return err('Reserved name') if $name eq 'root';
        return ok($name);
    }

    sub validate_age {
        my $age = shift;
        return err('No age') unless defined $age;
        return err('Invalid age') unless $age =~ /\A\d+\z/;
        return err('Too young age') if $age < 18;
        return ok($age);
    }

    result_for new_user => ValidUser, ArrayRef[ErrorMessage];

    sub new_user {
        my $args = shift;
        my @errors;

        my ($name, $name_err) = validate_name($args->{name});
        push @errors, $name_err if $name_err;

        my ($age, $age_err) = validate_age($args->{age});
        push @errors, $age_err if $age_err;

        return err(\@errors) if @errors;
        return ok({ name => $name, age => $age });
    }

    my ($user1, $err1) = new_user({ name => 'taro', age => 42 });
    is $user1, { name => 'taro', age => 42 };
    is $err1, undef;

    my ($user2, $err2) = new_user({ name => 'root', age => 1 });
    is $user2, undef;
    is $err2, ['Reserved name', 'Too young age'];

=head1 DESCRIPTION

Result::Simple is a dead simple Perl-ish Result.

Result represents a function's return value as success or failure, enabling safer error handling and more effective control flow management.
This pattern is used in other languages such as F#, Rust, and Go.

In Perl, this pattern is also useful, and this module provides a simple way to use it.
This module does not wrap a return value in an object. Just return a tuple like C<($data, undef)> or C<(undef, $err)>.

=head2 EXPORT FUNCTIONS

=head3 ok($value)

Return a tuple of a given value and undef. When the function succeeds, it should return this.

    sub add($a, $b) {
        ok($a + $b); # => ($a + $b, undef)
    }

=head3 err($error)

Return a tuple of undef and a given error. When the function fails, it should return this.

    sub div($a, $b) {
        return err('Division by zero') if $b == 0; # => (undef, 'Division by zero')
        ok($a / $b);
    }

Note that the error value must be a truthy value, otherwise it will throw an exception.

=head3 result_for $function_name => $T, $E

You can use the C<result_for> to define a function that returns a success or failure and asserts the return value types. Here is an example:

    result_for half => Int, ErrorMessage;

    sub half ($n) {
        if ($n % 2) {
            return err('Odd number');
        } else {
            return ok($n / 2);
        }
    }

=over 2

=item T (success type)

When the function succeeds, then returns C<($data, undef)>, and C<$data> should satisfy this type.

=item E (error type)

When the function fails, then returns C<(undef, $err)>, and C<$err> should satisfy this type.
Additionally, type E must be truthy value to distinguish between success and failure.

    result_for foo => Int, Str;

    sub foo ($input) { }
    # => throw exception: Result E should not allow falsy values: ["0"] because Str allows "0"

When a function never returns an error, you can set type E to C<undef>:

    result_for bar => Int, undef;
    sub double ($n) { ok($n * 2) }

=head3 unsafe_unwrap($data, $err)

C<unsafe_unwrap> takes a Result<T, E> and returns a T when the result is an Ok, otherwise it throws exception.
It should be used in tests or debugging code.

=head3 unsafe_unwrap_err($data, $err)

C<unsafe_unwrap_err> takes a Result<T, E> and returns an E when the result is an Err, otherwise it throws exception.
It should be used in tests or debugging code.

=back

Note that types require C<check> method that returns true or false. So you can use your favorite type constraint module like
L<Type::Tiny>, L<Moose>, L<Mouse> or L<Data::Checks> etc.

=head2 ENVIRONMENTS

=head3 C<$ENV{RESULT_SIMPLE_CHECK_ENABLED}>

If the C<ENV{RESULT_SIMPLE_CHECK_ENABLED}> environment is truthy before loading this module, it works as an assertion.
Otherwise, if it is falsy, C<result_for> attribute does nothing. The default is true.
This option is useful for development and testing mode, and it recommended to set it to false for production.

    result_for foo => Int, undef;
    sub foo { ok("hello") }

    my ($data, $err) = foo();
    # => throw exception when check enabled

=head1 NOTE

=head2 Avoiding Ambiguity in Result Handling

Forgetting to call C<ok> or C<err> function is a common mistake. Consider the following example:

    result_for validate_name => Str, ErrorMessage;

    sub validate_name ($name) {
        return "Empty name" unless $name; # Oops! Forgot to call `err` function.
        return ok($name);
    }

    my ($name, $err) = validate_name('');
    # => throw exception: Invalid result tuple (T, E)

In this case, the function throws an exception because the return value is not a valid result tuple C<($data, undef)> or C<(undef, $err)>.
This is fortunate, as the mistake is detected immediately. The following case is not detected:

    result_for foo => Str, ErrorMessage;

    sub foo {
        return (undef, 'apple'); # No use of `ok` or `err` function.
    }

    my ($data, $err) = foo;
    # => $err is 'apple'

Here, the function returns a valid failure tuple C<(undef, $err)>. However, it is unclear whether this was intentional or a mistake.
The lack of C<ok> or C<err> makes the intent ambiguous.

Conclusively, be sure to use C<ok> or C<err> functions to make it clear whether the success or failure is intentional.

=head2 Use alias name

You can use alias name for C<ok> and C<err> functions like this:

    use Result::Simple
        ok => { -as => 'left' },
        err => { -as => 'right' };

    left('foo'); # => ('foo', undef)
    right('bar'); # => (undef, 'bar')

=head1 LICENSE

Copyright (C) kobaken.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

kobaken E<lt>kentafly88@gmail.comE<gt>

=cut

