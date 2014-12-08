use strict;
use warnings;
package Data::Structure::Validation;
use Carp;

sub new{
    my $class = shift;
    my $config = shift || croak '$config not supplied';
    my $schema = shift || croak '$schema not supplied';

    my $self = {
        config => $config,
        schema => $schema,
    };
    bless ($self, $class);
    return $self;
}

sub parse_config{
    # load config
        # determine file or string
        # parse json

    # load schema
        # determine file or string
        # parse json

    # verify config against schema

}



=pod
=head1 Validate a Perl Data Structure with a Schema
=cut
1;
