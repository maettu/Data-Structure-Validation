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

sub __key_present_in_schema{
    my $key    = shift;
    my $config = shift;
    my $schema = shift;

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

            # only try to match a key if it has the property
            # _regex_ set
            next unless $schema->{$match_key}->{regex};

            if ($key =~ /$match_key/){
                say "$key matches $match_key";
                $key_schema_to_descend_into = $match_key;

            }
        }
    }
    # XXX how much sense does it make to have mandatory regex enabled keys?

    unless ($key_schema_to_descend_into){
        print " not there, keys available: ";
        print "'$_' " for (keys %{$schema});
        print "\n";
        say "bailout";
        exit;
    }
    return $key_schema_to_descend_into
}

sub __value_is_valid{
    my $key    = shift;
    my $config = shift;
    my $schema = shift;

    if (exists $schema->{$key}->{value}){
        say ref($schema->{$key}->{value});

        # currently, 2 type of restrictions are supported:
        # (callback) code and regex
        if (ref($schema->{$key}->{value}) eq 'CODE'){
            # XXX implement callback harness here (if needed)
        }
        elsif (ref($schema->{$key}->{value}) eq 'Regexp'){
            say "'$config->{$key}' should match '$schema->{$key}->{value}'";
            say "matches" if $config->{$key} =~ m/^$schema->{$key}->{value}$/;
        }
        else{
            say "neither CODE nor Regexp";
        }

    }
}

# this being sub for recursive tree traversal
sub _validate{
    my $config = shift;
    my $schema = shift;
    my $depth  = shift // 0;

    for my $key (keys %{$config}){
        print ' ' x ($depth*4), $key;

        # checks
        my $key_schema_to_descend_into =
            __key_present_in_schema($key, $config, $schema);
        __value_is_valid($key, $config, $schema);


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
