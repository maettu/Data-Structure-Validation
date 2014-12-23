#!/usr/bin/perl
use Test::More;

use lib 'lib';
use Data::Structure::Validation;

my $config = {
    top => {
        child => 42
    }
};

my $schema = {
    top => {
        members => {
            child => {
                validator => sub {
                    my $child = shift;
                    my $parent = shift;

                    return undef
                        if $parent->{child}->{value} == 42;
                }

            }
        }
    }
};

my $validator = Data::Structure::Validation->new($schema);

my @errors = $validator->validate($config, verbose=>0);

ok (scalar(@errors)==0, 'no errors');

done_testing;
