#!/usr/bin/perl
use Test::More;

use t::Helpers;
use lib 'lib';
use Data::Structure::Validation;

my $timespecfactor = {
    d => 24*3600,
    m => 60,
    s => 1,
    h => 3600
};

my $transformer = {
    timespec => sub {
        my $msg = shift;
        sub {
            if (shift =~ /^(\d+)([dmsh]?)$/){
                return ($1 * $timespecfactor->{($2 || 's')});
            }
            die {msg=>$msg};
        }
    }
};

my $schema = {
    history => {
        transformer => $transformer->{timespec}(
            'specify timeout in seconds or append d,m,h to the number'),
    },
};

my $config = {
    history => '1h',
};

my $validator = Data::Structure::Validation->new($schema);
my @errors = $validator->validate($config, verbose=>0);
ok ($config->{history} == 3600, 'transformed "1h" into "3600"');

$config = {
    history => 'regards, your error :-)',
};
@errors = $validator->validate($config);

ok ($config->{history} eq 'regards, your error :-)',
    'Could not transform "regards, your error :-)"');
ok ($errors[0]->{message} =~ /^error transforming 'history': specify/,
    'error from failed transform starts with "error transforming \'history\': specify"');


done_testing;
