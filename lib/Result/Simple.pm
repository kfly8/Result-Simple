package Result::Simple;
use strict;
use warnings;

our $VERSION = "0.01";

use Exporter 'import';

our @EXPORT = qw( Ok Err _ATTR_CODE_Result );

use Carp;
use Attribute::Handlers;
use Scope::Upper ();
use Sub::Util ();
use Scalar::Util ();

# If this option is true, then check `Ok` and `Err` functions usage and check a return value type.
# However it should be falsy for production code, because of performance and it is an assertion, not a validation.
use constant CHECK_ENABLED => $ENV{RESULT_SIMPLE_CHECK_ENABLED} // 0;

# Err does not allow these values.
use constant FALSY_VALUES => [0, '0', '', undef];

# When the function is successful, it should return this.
sub Ok {
    if (CHECK_ENABLED) {
        croak "`Ok` must be called in list context" unless wantarray;
    }
    ($_[0], undef)
}

# When the function fails, it should return this.
sub Err {
    if (CHECK_ENABLED) {
        croak "`Err` must be called in list context" unless wantarray;
        croak "`Err` does not allow a falsy value: @{[ _ddf($_[0]) ]}" unless $_[0];
    }
    (undef, $_[0])
}

# This attribute is used to define a function that returns a success or failure.
# Example: `sub foo :Result(Int, Error)  { ... }`
sub Result : ATTR(CODE) {
    return unless CHECK_ENABLED;

    my ($package, $symbol, $referent, $attr, $data, $phase, $filename, $line) = @_;
    my $name = *{$symbol}{NAME};

    my ($T, $E) = @$data;
    unless (Scalar::Util::blessed($T) && $T->can('check')) {
        croak "Result T requires `check` method, got: @{[ _ddf($T) ]} at $filename line $line\n";
    }

    unless (Scalar::Util::blessed($E) && $E->can('check')) {
        croak "Result E requires `check` method, got: @{[ _ddf($E) ]} at $filename line $line\n";
    }

    if (my @f = grep { $E->check($_) } @{ FALSY_VALUES() }) {
        croak "Result E should not allow falsy values: @{[ _ddf(\@f) ]} at $filename line $line\n";
    }

    wrap_code($referent, $package, $name, $T, $E);
}

# Wrap the original coderef with type check.
sub wrap_code {
    my ($code, $package, $name, $T, $E) = @_;

    my $wrapped = sub {
        croak "Must handle error in `$name`" unless wantarray;

        my ($data, $err) = &Scope::Upper::uplevel($code, @_, &Scope::Upper::CALLER(0));

        if ($err) {
            unless ($E->check($err)) {
                croak "Invalid error type in `$name`: ", _ddf($err);
            }
        } else {
            unless ($T->check($data)) {
                croak "Invalid data type in `$name`: ", _ddf($data);
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

=head1 DESCRIPTION

Result::Simple is a dead simple perl-ish Result.

Result represents a function's outcome as either success or failure, enabling safer error handling and more effective control flow management. This pattern is used in other languages such as F#, Rust, and Go.

In perl, this pattern is also useful. And this module provides a simple way to use it. This module does not wrap return value in an object. Just return a tuple of C<(Data, Undef)> or C<(Undef, Error)>.

=head2 EXPORT FUNCTIONS

=head3 Ok

    Ok($data) : ($data, undef)

Return a tuple of value and undef. When the function succeeds, it should return this.

=head3 Err

    Err($err) : (undef, $err)

Return a tuple of undef and error. When the function fails, it should return this.
Note that the error value should not be a falsy value, otherwise it will throw an exception.

=head2 ATTRIBUTES

=head3 :Result(T, E)

    sub foo :Result(Int, Error) ($input) {
        Ok('hello');
    }
    # => throw exception: Invalid data type in `foo`: "hello" (when CHECK_ENABLED is true)
    # => no exception (when CHECK_ENABLED is false)

This attribute is used to define a function that returns a success or failure.
Type T is the return type when the function is successful, and type E is the return type when the function fails.

Types requires C<check> method that returns true or false. So you can use your favorite type constraint module like
L<Type::Tiny>, L<Moose>, L<Mouse> or L<Data::Checks> etc. And type E should not allow falsy values.

    sub foo :Result(Int, Str) ($input) {
        ...
    }
    # => throw exception: Result E should not allow falsy values: ["0"]

If the C<RESULT_SIMPLE_CHECK_ENABLED> environment variable is set to a true value, the type check will be enabled.
This means that C<:Result> attribute does not do anything when the environment variable is false. It is useful for production code.

=head2 ENVIRONMENTS

=head3 C<$ENV{RESULT_SIMPLE_CHECK_ENABLED}>

If this environment variable is set to a true value, the type check will be enabled. Default is false.

    BEGIN {
        $ENV{RESULT_SIMPLE_CHECK_ENABLED} = 1;
    }

=head1 LICENSE

Copyright (C) kobaken.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

kobaken E<lt>kentafly88@gmail.comE<gt>

=cut

