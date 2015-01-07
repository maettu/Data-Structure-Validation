#!/usr/bin/perl
use Test::More;

use lib 'lib';
use Data::Structure::Validation;

my $schema = {
    'foo.*' => {
        regex => 1,
        members => {
            one => {
                value => qr{what.*}
            },
            two => {
                value => qr{something.*}
            }
        }
    },
    bar => {
        members => {
            bar_one => {
                value => qr{not_there}
            }
        }
    },
};

my $config = {
    'fooo' => {
        one => 'whatever',
        two => 'something else'
    },
    'foo'  => 'error: members missing',
    'fo'   => 'not in schema',

    bar => 'empty'
};

my $validator = Data::Structure::Validation->new($schema);

my @errors = $validator->validate($config, verbose=>1);

use Data::Dumper; print Dumper \@errors;
