#!/usr/bin/perl
use Test::More;

use lib 'lib';
use Config::Structure::ValidatorFactory;

my $vf = Config::Structure::ValidatatorFactory->new;

like ($vf->file('<','oops')->('/tmp/xkddf'),qr/oops/, 'error message generated');
is ($vf->rx(qr{XX},'oops')->('xxXXx'),undef,'regular expression check');
is ($vf->any(qw(OFF ON))->('OFF'),undef, 'is it one of the list');


done_testing;
