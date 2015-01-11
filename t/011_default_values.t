#!/usr/bin/perl
use Test::More;

use t::Helpers;
use lib 'lib';
use Data::Structure::Validation;

my $schema = {
    key_with_default_value => {
        default => 42
    }
};

my $config = {};


my $validator = Data::Structure::Validation->new($schema);

my @errors = $validator->validate($config, verbose=>0);

ok ($config->{key_with_default_value}==42,
    'key_with_default_value 42 inserted');

done_testing;
