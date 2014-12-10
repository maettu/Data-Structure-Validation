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
        mandatory   => 1,
        description => 'general settings',
        error-msg   => 'Section GENERAL missing',
        members => {
            logfile => {
                value       => qr{/.*},
                # or a coderef: value => sub{return 1},
                description => 'absolute path to logfile',
                mandatory   => 1,
            },
            cachedb => {
                value => qr{/.*},
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
                members => {
                    'silo-.+' => {
                        regex => 1,
                        members => {
                            url => {
                                mandatory   => 1,
                                value       => qr{https.*},
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

