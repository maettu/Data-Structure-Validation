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

# this being sub for recursive tree traversal
sub _validate{
    my $config = shift;
    my $schema = shift;
    my $depth  = shift // 0;

    for my $key (keys %{$config}){
        print ' ' x ($depth*4), $key;

        my $key_schema_to_descend_into;

        # direct match: exact declaration
        if (exists $schema->{$key}){
            say " ok";
            $key_schema_to_descend_into = $key;
        }
        # match against a pattern
        else {
            my $match;
            for my $match_key (keys %{$schema}){
                # TODO look if $schema-key is match enabled
                if ($key =~ /$match_key/){
                    say "$key matches $match_key";
                    $key_schema_to_descend_into = $match_key;

                }
            }

            unless ($key_schema_to_descend_into){
                print " not there, keys available: ";
                print "'$_' " for (keys %{$schema});
                print "\n";
                say "bailout";
                exit;
            }
        }

        # XXX how much sense does it make to have mandatory regex enabled keys?

        # recursion
        if (ref $config->{$key} eq ref {}){
            _validate( $config->{$key}, $schema->{$key_schema_to_descend_into}->{members}, $depth+1);
        }

        # TODO
    }

    # look for missing mandatory keys in schema
    # this is only done on this level.
    # Otherwise "mandatory" inherited "upwards".
    _check_mandatory_keys($config, $schema);



}

# check mandatory: look for mandatory fields in all hashes 1 level
# below current level (in schema)
# for each check if $config has a key.
sub _check_mandatory_keys{
    my $config = shift;
    my $schema = shift;

    # TODO
}


# check if everything in config is in line with schema
sub validate{
    my $self = shift;

    _validate($self->{config}, $self->{schema});
}

=pod
=head1 Validate a Perl Data Structure with a Schema
=cut
1;
