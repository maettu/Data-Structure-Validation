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
                _value_       =>  {
                    _string_ => '^/',
                    # could be 'regex', 'comparison', 'range', ..?
                    _type_   => 'regex'
                },
                _description_ =>  'absolute path to logfile',
                _mandatory_   => 1,
            },
            cachedb => {
#~                 _value_ => 'qx{^/}',
                _description_ => 'absolute path to cache (sqlite) database file',
                _mandatory_ => 1,
            },
            history => {
                _mandatory_ => 1,
            },
            silos => {
                _mandatory_   => 1,
                _description_ => 'silos store collected data',
                # "members" stands for all "non-internal" fields
                _members_ => {
                    'silo-.+' => {
                        _regex_ => 1,
                        _members_ => {
                            url => {
                                _mandatory_   => 1,
#~                                 _value_       => 'qx{^https}',
                                _description_ => 'url of the silo server. Only https:// allowed',
                            },
                            key => {
                                _mandatory_   => 1,
                                _description_ => 'shared secret to identify node'
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

