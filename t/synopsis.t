use Test2::V0 qw(is done_testing);
use Test2::Require::Module 'Type::Tiny' => '2.000000';
use Test2::Require::Module 'kura';

# Enable type check. The default is false.
BEGIN { $ENV{RESULT_SIMPLE_CHECK_ENABLED} = 1 }

use Result::Simple qw( ok err result_for );
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

done_testing
