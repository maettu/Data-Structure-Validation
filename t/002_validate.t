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
                                example     => 'https://silo-a/api',
                                description => 'url of the silo server. Only https:// allowed',
                            },
                            key => {
                                mandatory   => 1,
                                description => 'shared secret to identify node'
                            },
                            not_existing => {
                                mandatory => 1,
                            }
                        }
                    }
                }
            }
        }
    },
    NOT_THERE => {
        mandatory => 1
    }
};

eval {Data::Structure::Validation->new(undef)};
ok ($@, '$config not supplied');

eval {Data::Structure::Validation->($config, undef)};
ok ($@, '$schema not supplied');

my $validator = Data::Structure::Validation->new($schema);
isa_ok( $validator, Data::Structure::Validation, '$checker' );

can_ok($validator, validate);

my @errors = $validator->validate($config, verbose=>0);

ok (scalar(@errors)==2, '2 errors found');

sub _any_error_contains {
    my $string = shift;
    for my $error (@errors){
        return 1 if $error =~ /$string/;
    }
    return undef;
}

ok (_any_error_contains("not_existing"), "mandatory schema key 'not_existing' not in config");
ok (_any_error_contains("NOT_THERE"), "mandatory schema section 'NOT_THERE' not found in config");
ok (_any_error_contains("silo-a"), "missing value from 'silo-a'");
ok (_any_error_contains("Path: root"), "section missing from 'root'");

@errors = $validator->validate($config, verbose=>0);

$config = {
    GENERAL => {
        logfile => '/tmp/n3k-poller.log',
        cachedb => '/tmp/n3k-cache.db',
        history => '3d',
        silos   => {
            'silo-a' => {
                url => 'https://silo-a/api',
                key => 'my-secret-shared-key',
                not_existing => 'make go away my error!',
            }
        }
    },
    NOT_THERE => 'whatnot'
};

@errors = $validator->validate($config, verbose=>0);
ok (@errors == (), 'no more errors with corrected config');


my $config_template = $validator->make_config_template(verbose => 1);

ok (exists $config_template->{GENERAL}, 'section "GENERAL" exists');
ok (exists $config_template->{GENERAL}->{logfile}, '"logfile" exists');
ok ($config_template->{GENERAL}->{logfile} = 'absolute path to logfile (?-xism:/.*)', 'logifle has correct content');


done_testing();

