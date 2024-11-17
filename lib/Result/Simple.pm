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

    my ($package, $symbol, $referent, $attr, $data) = @_;
    my $name = *{$symbol}{NAME};

    my ($T, $E) = @$data;
    wrap_code($referent, $package, $name, $T, $E);
}

sub wrap_code {
    my ($code, $package, $name, $T, $E) = @_;

    unless (Scalar::Util::blessed($T) && $T->can('check')) {
        croak "Invalid type object for $name (T)";
    }

    unless (Scalar::Util::blessed($E) && $E->can('check')) {
        croak "Invalid type object for $name (E)";
    }

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

Result::Simple - It's new $module

=head1 SYNOPSIS

    use Result::Simple;

=head1 DESCRIPTION

Result::Simple is ...

=head1 LICENSE

Copyright (C) kobaken.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

kobaken E<lt>kentafly88@gmail.comE<gt>

=cut

