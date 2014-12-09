use 5.10.1;
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

sub validate{
    my $self   = shift;
    my $config = $self->{config};
    my $schema = $self->{schema};

    # check if everything in config is in line with schema

    for my $key (keys %{$config}){
        say $key;

        # Unterschied zwischen expliziten keys (GENERAL) und solchen, die
        # "nur" da sein müssen ("silo-a", "silo-b" usw)
        if (exists $schema->{$key}){
            say "$key gefunden";
#~             use Data::Dumper; say Dumper $schema->{$key};
            for my $schema_key (keys %{$schema->{$key}}){
                say "    $schema_key";
            }
        }
        else {
            say "$key not there";
        }

    }

    # check if all mandatory fields are there
    say "###############";
    _check_mandatory($config, $schema, 0);
    say "###############";

#~     use Data::Dumper; say Dumper $schema;
}

sub _check_mandatory {
    my $config = shift;
    my $schema = shift;
    my $depth  = shift // 0;


    for my $key (keys %{$schema}){

        # check here

        print ' ' x $depth, $key;

        if (ref $schema->{$key} eq ref {}){
            if (exists $schema->{$key}->{mandatory}
                    and
                $schema->{$key}->{mandatory}){

                print "  ($key is mandatory)";

                say "\n*** Error *** $key not found"
                    unless (exists $config->{$key});

            }
            print "\n";

            if ($key eq 'members'){
                say "wohoo 'members'";
                # injecting keys for all members found in $config into $schema?
            }

            _check_mandatory($config->{$key}, $schema->{$key}, $depth+4)
        }
        else {
            say ": $schema->{$key}";
        }
    }
}



=pod
=head1 Validate a Perl Data Structure with a Schema
=cut
1;
