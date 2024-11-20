package Result::Simple;
use strict;
use warnings;

our $VERSION = "0.01";

use Exporter 'import';

our @EXPORT = qw( Ok Err );

use Carp;
use Attribute::Handlers;
use Scope::Upper ();
use Sub::Util ();
use Scalar::Util ();

use constant CHECK_ENABLED => $ENV{RESULT_SIMPLE_CHECK_ENABLED} // 0;

use constant true  => !0;
use constant false => !1;

sub Ok {
    croak "Must be called in list context" unless wantarray;
    (true, @_)
}

sub Err {
    croak "Must be called in list context" unless wantarray;
    (false, @_)
}

sub UNIVERSAL::Result : ATTR(CODE) {
    return unless CHECK_ENABLED;

    my ($package, $symbol, $referent, $attr, $data, $phase, $filename, $line) = @_;
    my $name = *{$symbol}{NAME};

    my ($T, $E) = @$data;
    unless (Scalar::Util::blessed($T) && $T->can('check')) {
        die "Result T requires `check` method, got: @{[ _ddf($T) ]} at $filename line $line\n";
    }

    unless (Scalar::Util::blessed($E) && $E->can('check')) {
        die "Result E requires `check` method, got: @{[ _ddf($E) ]} at $filename line $line\n";
    }

    wrap_code($referent, $package, $name, $T, $E);
}

sub wrap_code {
    my ($code, $package, $name, $T, $E) = @_;

    my $wrapped = sub {
        croak "Must be called in list context" unless wantarray;

        my ($ok, $result) = &Scope::Upper::uplevel($code, @_, &Scope::Upper::CALLER(0));

        if ($ok) {
            unless ($T->check($result)) {
                croak "Invalid data type in $name: ", _ddf($result);
            }
        } else {
            unless ($E->check($result)) {
                croak "Invalid error type in $name: ", _ddf($result);
            }
        }

        ($ok, $result);
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

sub _ddf {
    my $v = shift;

    no warnings 'once';
    require Data::Dumper;
    local $Data::Dumper::Indent   = 0;
    local $Data::Dumper::Useqq    = 1;
    local $Data::Dumper::Terse    = 1;
    local $Data::Dumper::Sortkeys = 1;
    local $Data::Dumper::Maxdepth = 2;
    Data::Dumper::Dumper($v);
}

1;
__END__

=encoding utf-8

=head1 NAME

Result::Simple - dead simple perl-ish result type

=head1 SYNOPSIS

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

=head1 DESCRIPTION

This module provides a simple way to define functions that return a result type. This data type is similar to Go, Rust's Result type.

=head2 EXPORT

=head3 Ok

    Ok(@values) : ($ok, @values)

Return a tuple of true and values. When the function is successful, it should return this.
Can be used in list context:

    my $a = Ok(42); # dies with "Must be called in list context"

=head3 Err

    Err(@values) : ($ok, @values)

Return a tuple of false and values. When the function fails, it should return this.
Can be used in list context:

    my $a = Err('error'); # dies with "Must be called in list context"

=head2 ATTRIBUTES

=head3 :Result(T, E)

    sub foo :Result(Int, Str) ($input) {
        ...
    }

This attribute is used to define a function that returns a result type.
Type T is the return type when the function is successful, and type E is the return type when the function fails.
Types requires C<check> method that returns true or false. So you can use L<Types::Standard> or L<Data::Checks> etc.

If the C<RESULT_SIMPLE_CHECK_ENABLED> environment variable is set to a true value, the type check will be enabled.

=head2 ENVIRONMENTS

=head3 RESULT_SIMPLE_CHECK_ENABLED

If this environment variable is set to a true value, the type check will be enabled. Default is false.

=head1 LICENSE

Copyright (C) kobaken.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

kobaken E<lt>kentafly88@gmail.comE<gt>

=cut

