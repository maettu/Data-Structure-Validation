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
    my $key            = shift;
    my $config_section = shift;
    my $schema_section = shift;

    my $key_schema_to_descend_into;

    # direct match: exact declaration
    if (exists $schema_section->{$key}){
        say " ok";
        $key_schema_to_descend_into = $key;
    }
    # match against a pattern
    else {
        my $match;
        for my $match_key (keys %{$schema_section}){

            # only try to match a key if it has the property
            # _regex_ set
            next unless $schema_section->{$match_key}->{regex};

            if ($key =~ /$match_key/){
                say "$key matches $match_key";
                $key_schema_to_descend_into = $match_key;

            }
        }
    }
    # XXX how much sense does it make to have mandatory regex enabled keys?

    unless ($key_schema_to_descend_into){
        print " not there, keys available: ";
        print "'$_' " for (keys %{$schema_section});
        print "\n";
        say "bailout";
        exit;
    }
    return $key_schema_to_descend_into
}

sub __value_is_valid{
    my $key    = shift;
    my $config_section = shift;
    my $schema_section = shift;
    my $depth          = shift;

    if (exists $schema_section->{$key}->{value}){
        say ' 'x($depth*4), ref($schema_section->{$key}->{value});

        # currently, 2 type of restrictions are supported:
        # (callback) code and regex
        if (ref($schema_section->{$key}->{value}) eq 'CODE'){
            # XXX implement callback harness here (if needed)
        }
        elsif (ref($schema_section->{$key}->{value}) eq 'Regexp'){
            say ' 'x($depth*4), "'$config_section->{$key}' should match '$schema_section->{$key}->{value}'";
            say ' 'x($depth*4), "matches" if $config_section->{$key} =~ m/^$schema_section->{$key}->{value}$/;
        }
        else{
            say ' 'x($depth*4), "neither CODE nor Regexp";
        }

    }
}

# this being sub for recursive tree traversal
sub _validate{
    # $(word)_section are *not* the data fields but the sections of the
    # config / schema the recursive algorithm is currently working on.
    # (Only) in the first call, these are identical.
    my $config_section = shift;
    my $schema_section = shift;
    my $depth          = shift // 0;

    for my $key (keys %{$config_section}){
        print ' ' x ($depth*4), $key;

        # checks
        my $key_schema_to_descend_into =
            __key_present_in_schema($key, $config_section, $schema_section);
        __value_is_valid($key, $config_section, $schema_section, $depth);


        # recursion
        if (ref $config_section->{$key} eq ref {}){
            _validate(
                $config_section->{$key},
                $schema_section->{$key_schema_to_descend_into}->{members},
                $depth+1
            );
        }
    }

    # look for missing mandatory keys in schema
    # this is only done on this level.
    # Otherwise "mandatory" inherited "upwards".
    _check_mandatory_keys($config_section, $schema_section, $depth);

}

# check mandatory: look for mandatory fields in all hashes 1 level
# below current level (in schema)
# for each check if $config has a key.
sub _check_mandatory_keys{
    my $config_section = shift;
    my $schema_section = shift;
    my $depth          = shift;

    for my $key (keys %{$schema_section}){
        print ' 'x($depth*4), "Checking if $key is mandatory: ";
        if (exists $schema_section->{$key}->{mandatory}
               and $schema_section->{$key}->{mandatory}){

            say "true";
        }
        else{
            say "false";
        }

    }
}


# TODO rename $config & $schema in subs.
# These are only parts of the whole thing (first call excluded).

# check if everything in config is in line with schema
sub validate{
    my $self = shift;

    # start (recursive) validation with top level elements
    _validate($self->{config}, $self->{schema});
}

=pod
=head1 Validate a Perl Data Structure with a Schema
=cut
1;
