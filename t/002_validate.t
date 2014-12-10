#!/usr/bin/perl
use Test::More;

use lib 'lib';
use Data::Structure::Validation;

my $config = {
    GENERAL => {
        logfile => '/tmp/n3k-poller.log',
        cachedb => '/tmp/n3k-cache.db',
        history => '3d',
        silos   => {
            'silo-a' => {
                url => 'https://silo-a/api',
                key => 'my-secret-shared-key',
            }
        }

    }
};

my $schema = {
    GENERAL => {
        _mandatory_   => 1,
        _description_ => 'general settings',
        _error-msg_   => 'Section GENERAL missing',
        _members_ => {
            logfile => {
                value       =>  'qx{^/}',
                description =>  'absolute path to logfile',
                mandatory   => 1,
            },
            cachedb => {
                value => 'qx{^/}',
                description => 'absolute path to cache (sqlite) database file',
                mandatory => 1,
            },
            history => {
                mandatory => 1,
            },
            silos => {
                mandatory   => 1,
                description => 'silos store collected data',
                # "members" stands for all "non-internal" fields
                _members_ => {
                    'silo-.+' => {
#~                         _regex_ => 1,
                        _members_ => {
                            url => {
                                mandatory   => 1,
                                value       => 'qx{^https}',
                                description => 'url of the silo server. Only https:// allowed',
                            },
                            key => {
                                mandatory   => 1,
                                description => 'shared secret to identify node'
                            }
                        }
                    }
                }
            }
        }
    }
};

eval {Data::Structure::Validation->new(undef)};
ok ($@, '$config not supplied');

eval {Data::Structure::Validation->($config, undef)};
ok ($@, '$schema not supplied');

my $validator = Data::Structure::Validation->new($config, $schema);
isa_ok( $validator, Data::Structure::Validation, '$checker' );

can_ok($validator, validate);

$validator->validate();



done_testing();

