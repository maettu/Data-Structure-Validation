use 5.10.1;
use strict;
use warnings;
package Data::Structure::Validation;
use Carp;

my $verbose;
my @errors;      # this will be collecting all errors

##################
# (public) methods
##################

sub new{
    my $class  = shift;
    my $schema = shift || croak '$schema not supplied';
    $verbose   = shift;


    my $self = {
        schema  => $schema,
    };
    bless ($self, $class);
    return $self;
}

# check if everything in config is in line with schema
sub validate{
    my $self   = shift;
    my $config = shift || croak '$config not supplied';
    my %p      = @_;
    _reset_globals();
    $verbose = 1 if exists $p{verbose} and $p{verbose};

    # start (recursive) validation with top level elements
    _validate($config, $self->{schema}, 0, 'root');
    return @errors;
}

# produce a config template from the schema given
sub make_config_template{
    my $self = shift;
    my %p    = @_;
    _reset_globals();
    $verbose = 1 if exists $p{verbose} and $p{verbose};
    my $entry_point = $p{entry_point} // 'root';
    my $config = _make_config_template($self->{schema}, $entry_point, 0);
    return $config;
}


#################
# (internal) subs
#################

sub _reset_globals{
    $verbose = undef;
    @errors  = ();
}

# XXX bailout without "@parent_keys"
sub bailout ($@) {
    my $string = shift;
    my @parent_keys = @_;
    my $msg_parent_keys = join '->', @parent_keys;
    my (undef, undef, $line) = caller(0);
    my (undef, undef, undef, $sub) = caller(1);
    push @errors, "$string (Path: $msg_parent_keys) caller: $sub line $line";

}

# this is not an object method because it is a helper sub for internal
# use and not a method that describes an object.
sub explain ($) {
    my $string = shift;
    # XXX enable multiple verbosity levels
    print $string if $verbose;
}

# make template: recursive tree traversal
sub _make_config_template{
    my $schema_section = shift;
    my $entry_point    = shift;
    my $depth          = shift;
    # as soon as entry_point was found, config is recorded
    my $record_flag    = shift;

    my $config = {};

    for my $key (sort keys %{$schema_section}){

        # config keys always are hashes in schema.
        if (ref $schema_section->{$key} eq ref {} ){
            my $depth_add;
            if ($key eq 'members'){
                # "members" indicates children but is not written in config
                $depth_add = 0;
                return _make_config_template(
                    $schema_section->{$key},
                    $entry_point,
                    $depth+$depth_add,
                    $record_flag
                );
            }
            else{
                $depth_add = 1;
                explain ' ' x ($depth*4). "$key";

                if (exists $schema_section->{$key}->{description}){
                    explain " => $schema_section->{$key}->{description}";
                    $config->{$key} = $schema_section->{$key}->{description}
                }

                if (exists $schema_section->{$key}->{value}){
                    explain " $schema_section->{$key}->{value}";
                    $config->{$key} .= ' '.$schema_section->{$key}->{value};
                }
                explain "\n";

                if (! exists  $schema_section->{$key}->{value}){
                    $config->{$key} = _make_config_template(
                        $schema_section->{$key},
                        $entry_point,
                        $depth+$depth_add,
                        $record_flag,
                    );
                }
            }

        }
    }
    return $config;
}

# validate: recursive tree traversal
sub _validate{
    # $(word)_section are *not* the data fields but the sections of the
    # config / schema the recursive algorithm is currently working on.
    # (Only) in the first call, these are identical.
    my $config_section = shift;
    my $schema_section = shift;
    my $depth          = shift // 0;
    my @parent_keys    = @_;

    for my $key (keys %{$config_section}){
        explain ' ' x ($depth*4). "'$key'";
        # checks
        my $key_schema_to_descend_into =
            __key_present_in_schema(
                $key, $config_section, $schema_section, @parent_keys
            );

        __value_is_valid(
            $key, $config_section, $schema_section, $depth, @parent_keys
        );

        __validator_returns_undef(
            $key, $config_section, $schema_section, $depth, @parent_keys
        ) if exists $schema_section->{$key}
             and exists $schema_section->{$key}->{validator};

        my $descend_into;
        if (exists  $schema_section->{$key}
                and $schema_section->{$key}->{no_descend_into}
                and $schema_section->{$key}->{no_descend_into}){
            explain "skipping $key\n";
        }
        else{
            $descend_into = 1;
        }

        # recursion
        if ((ref $config_section->{$key} eq ref {})
                and $descend_into){
            push @parent_keys, $key;
            _validate(
                $config_section->{$key},
                $schema_section->{$key_schema_to_descend_into}->{members},
                $depth+1,
                @parent_keys
            );
            # to undo push before entering recursion.
            pop @parent_keys;
        }
    }

    # look for missing mandatory keys in schema
    # this is only done on this level.
    # Otherwise "mandatory" inherited "upwards".
    _check_mandatory_keys(
        $config_section, $schema_section, $depth, @parent_keys
    );

}



# called by _validate to check if a given key is defined in schema
sub __key_present_in_schema{
    my $key            = shift;
    my $config_section = shift;
    my $schema_section = shift;
    my @parent_keys    = @_;

    my $key_schema_to_descend_into;

    # direct match: exact declaration
    if (exists $schema_section->{$key}){
        explain " ok\n";
        $key_schema_to_descend_into = $key;
    }
    # match against a pattern
    else {
        my $match;
        for my $match_key (keys %{$schema_section}){

            # only try to match a key if it has the property
            # _regex_ set
            next unless exists $schema_section->{$match_key}
                    and exists $schema_section->{$match_key}->{regex}
                           and $schema_section->{$match_key}->{regex};

            if ($key =~ /$match_key/){
                explain "'$key' matches $match_key\n";
                $key_schema_to_descend_into = $match_key;
            }
        }
    }
    # XXX how much sense does it make to have mandatory regex enabled keys?

    # if $key_schema_to_descend_into is still undef we were unable to
    # match it against a key in the schema.
    unless ($key_schema_to_descend_into){
        explain "$key not in schema, keys available: ";
        explain "'$_' " for (keys %{$schema_section});
        explain "\n";
        bailout "key '$key' not found in schema\n", @parent_keys;
    }
    return $key_schema_to_descend_into
}

# called by _validate to check if a value is in line with definitions
# in the schema.
sub __value_is_valid{
    my $key    = shift;
    my $config_section = shift;
    my $schema_section = shift;
    my $depth          = shift;
    my @parent_keys    = @_;

    if (exists  $schema_section->{$key}
            and $schema_section->{$key}->{value}){
        explain ' 'x($depth*4). ref($schema_section->{$key}->{value})."\n";

        # currently, 2 type of restrictions are supported:
        # (callback) code and regex
        if (ref($schema_section->{$key}->{value}) eq 'CODE'){
            # XXX implement callback harness here (if needed)
            # possibly never implement this because of new "validator"
        }
        elsif (ref($schema_section->{$key}->{value}) eq 'Regexp'){
            explain ' 'x($depth*4). "match '$config_section->{$key}' against '$schema_section->{$key}->{value}'";

            if ($config_section->{$key} =~ m/^$schema_section->{$key}->{value}$/){
                explain " ok.\n"
            }
            else{
                explain " no.\n";
                bailout "$config_section->{$key} does not match ^$schema_section->{$key}->{value}\$", @parent_keys;
            }
        }
        else{
            # XXX match literally? How much sense does this make?!

            explain ' 'x($depth*4). "neither CODE nor Regexp\n";
            bailout "'$key' not CODE or Regexp", @parent_keys;
        }

    }
}

sub __validator_returns_undef {
my $key    = shift;
    my $config_section = shift;
    my $schema_section = shift;
    my $depth          = shift;
    my @parent_keys    = @_;
    explain ' 'x($depth*4). "running validator for '$key': $config_section->{$key}\n";
    my $return_value = $schema_section->{$key}->{validator}->($config_section->{$key});
    if ($return_value){
        explain ' 'x($depth*4)."validator error: $return_value\n";
        bailout "Execution of validator for '$key' returns with error: $return_value", @parent_keys;
    }
    else {
        explain ' 'x($depth*4). "successful validation for key '$key'\n";
    }
}

# check mandatory: look for mandatory fields in all hashes 1 level
# below current level (in schema)
# for each check if $config has a key.
sub _check_mandatory_keys{
    my $config_section = shift;
    my $schema_section = shift;
    my $depth          = shift;
    my @parent_keys    = @_;

    for my $key (keys %{$schema_section}){
        explain ' 'x($depth*4). "Checking if '$key' is mandatory: ";
        if (exists $schema_section->{$key}->{mandatory}
               and $schema_section->{$key}->{mandatory}){

            explain "true\n";
            bailout "mandatory key '$key' missing", @parent_keys
                unless exists $config_section->{$key};
        }
        else{
            explain "false\n";
        }
    }
}


=pod
=head1 Validate a Perl Data Structure with a Schema
=cut
1;
