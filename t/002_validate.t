#!/usr/bin/perl
use Test::More;

use t::Helpers;
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
        description => 'general settings',
        error_msg   => 'Section GENERAL missing',
        members => {
            logfile => {
                value       => qr{/.*},
                # or a coderef: value => sub{return 1},
                description => 'absolute path to logfile',
            },
            cachedb => {
                value => qr{/.*},
                description => 'absolute path to cache (sqlite) database file',
            },
            history => {
            },
            silos => {
                description => 'silos store collected data',
                # "members" stands for all "non-internal" fields
                members => {
                    'silo-.+' => {
                        regex => 1,
                        members => {
                            url => {
                                value       => qr{https.*},
                                example     => 'https://silo-a/api',
                                description => 'url of the silo server. Only https:// allowed',
                            },
                            key => {
                                description => 'shared secret to identify node'
                            },
                            not_existing => {
                            }
                        }
                    }
                }
            }
        }
    },
    NOT_THERE => {
        error_msg => 'We shall not proceed without a section that is NOT_THERE',
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

ok (t::Helpers::any_error_contains("not_existing", 'message', @errors),
    "mandatory schema key 'not_existing' not in config");

ok (t::Helpers::any_error_contains("NOT_THERE", 'message', @errors),
    "mandatory schema section 'NOT_THERE' not found in config");

ok (t::Helpers::any_error_contains("silo-a", 'path', @errors),
    "missing value from 'silo-a'");

ok (t::Helpers::any_error_contains("root", 'path', @errors),
    "section missing from 'root'");

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


my $config_template = $validator->make_config_template(verbose => 0);

ok (exists $config_template->{GENERAL}, 'section "GENERAL" exists');
ok (exists $config_template->{GENERAL}->{logfile}, '"logfile" exists');
ok ($config_template->{GENERAL}->{logfile} = 'absolute path to logfile (?-xism:/.*)', 'logifle has correct content');

my $config_template = $validator->make_config_template(entry_point => $schema->{GENERAL}->{members}->{silos});
ok (exists $config_template->{'silo-.+'}, 'entry point "silos" found');
ok ($config_template->{'silo-.+'}->{url} eq 'url of the silo server. Only https:// allowed(?^:https.*)',
    'url has correct content');

# check error messages from schema.
$config = {

};

@errors = $validator->validate($config, verbose=>0);
ok (scalar(@errors) == 2, '2 errors');
ok (t::Helpers::any_error_contains(
        "We shall not proceed without a section that is NOT_THERE",
        'message',
        @errors),
    'correct error msg');

done_testing();

