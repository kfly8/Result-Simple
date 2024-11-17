requires 'perl', '5.014004';

requires 'Attribute::Handlers';
requires 'Scope::Upper';
requires 'Sub::Util';
requires 'Scalar::Util';

on 'test' => sub {
    requires 'Test::More', '0.98';
};
