requires 'perl', '5.014004';

requires 'Attribute::Handlers';
requires 'Scope::Upper';
requires 'Sub::Util';
requires 'Scalar::Util';

on 'configure' => sub {
    requires 'Module::Build::Tiny', '0.035';
};

on 'test' => sub {
    requires 'Test::More', '0.98';
};
