use Test2::V0 qw(is done_testing);
use Test2::Require::Module 'Type::Tiny' => '2.000000';
use Test2::Require::Module 'kura';

use Result::Simple qw( ok err result_for );
use Types::Standard -types;

use kura Error   => Dict[message => Str];
use kura Request => Dict[name => Str, age => Int];

result_for validate_name => Str, Error;

sub validate_name {
    my $name = shift;
    return err({ message => 'No name'}) unless defined $name;
    return err({ message => 'Empty name'}) unless length $name;
    return err({ message => 'Reserved name'}) if $name eq 'root';
    return ok($name);
}

result_for validate_age => Int, Error;

sub validate_age {
    my $age = shift;
    return err({ message => 'No age'}) unless defined $age;
    return err({ message => 'Invalid age'}) unless $age =~ /\A\d+\z/;
    return err({ message => 'Too young age'}) if $age < 18;
    return ok($age);
}

result_for validate_req => Request, Error;

sub validate_req {
    my $args = shift;

    # my $name = validate_name($args->{name}); # => Throw error! It requires list context to handle error
    my ($name, $name_err) = validate_name($args->{name});
    return err($name_err) if $name_err;

    my ($age, $age_err) = validate_age($args->{age});
    return err($age_err) if $age_err;

    return ok({ name => $name, age => $age });
}

my ($req1, $err1) = validate_req({ name => 'taro', age => 42 });
is $req1, { name => 'taro', age => 42 };
is $err1, undef;

my ($req2, $err2) = validate_req({ name => 'root', age => 20 });
is $req2, undef;
is $err2, { message => 'Reserved name' };

done_testing
