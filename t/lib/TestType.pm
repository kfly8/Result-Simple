package TestType;
use strict;
use warnings;

use Exporter 'import';

our @EXPORT_OK = qw( Int Str );

{
    package TestType::Object;

    sub new {
        my ($class, $check ) = @_;
        bless { check => $check }, $class;
    }

    sub check {
        my ($self, $value) = @_;
        $self->{check}->($value);
    }
}

sub Int() { TestType::Object->new(sub { $_[0] =~ /^-?\d+$/ }) }
sub Str() { TestType::Object->new(sub { defined $_[0] && !ref $_[0] }) }

1;
