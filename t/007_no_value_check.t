#!/usr/bin/perl
use Test::More;

use t::Helpers;
use lib 'lib';
use Data::Structure::Validation;

my $schema = {
    probe_cfg => {
    }
};

my $config = {
    probe_cfg => 'dummy entry.'

};

my $validator = Data::Structure::Validation->new($schema);

my @errors = $validator->validate($config, verbose=>1);

ok (scalar(@errors)==0, 'no errors');

done_testing;
