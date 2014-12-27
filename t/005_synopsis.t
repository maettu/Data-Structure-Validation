#!/usr/bin/perl
use Test::More;

use lib 'lib';
use Data::Structure::Validation;

my $schema = {
    section => {
        mandatory   => 1,
        description => 'a section with a few members',
        error_msg   => 'cannot find "section" in config',
        members => {
            foo => {
                # value restriction either with a regex..
                value => qr{f.*},
                description => 'a string beginning with "f"'
            },
            bar => {
                # ..or with a validator callback.
                validator => sub {
                    my $self   = shift;
                    my $parent = shift;
                    # undef is "no-error" -> success.
                    return undef
                        if $self->{value} == 42;
                }
            }
        }
    }
};

my $validator = Data::Structure::Validation->new($schema);

my $config = {
    section => {
        foo => 'frobnicate',
        bar => 42,
    }
};

my @errors = $validator->validate($config, verbose=>0);
# no errors :-)

ok (scalar(@errors)==0, 'no errors');

done_testing;
