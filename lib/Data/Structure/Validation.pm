use 5.10.1;
use strict;
use warnings;
package Data::Structure::Validation;
use Data::Structure::Validation::Error::Collection;
# ABSTRACT: Validate a Perl Data Structure with a Schema
use Carp;

our $VERSION = '0.0.0';

##################
# (public) methods
##################

sub new{
    my $class  = shift;
    my $schema = shift || croak '$schema not supplied';
    my $verbose   = shift;


    my $self = {
        schema  => $schema,
        errors  => Data::Structure::Validation::Error::Collection->new(),
        verbose => $verbose,
    };
    bless ($self, $class);
    return $self;
}

# check if everything in config is in line with schema
sub validate{
    my $self   = shift;
    my $config = shift || croak '$config not supplied';
    my %p      = @_;
    $self->_reset_globals();
    $self->{verbose} = 1 if exists $p{verbose} and $p{verbose};

    # start (recursive) validation with top level elements
    $self->_validate($config, $self->{schema}, 0, 'root');
    return $self->{errors}->as_array();
}

# produce a config template from the schema given
sub make_config_template{
    my $self = shift;
    my %p    = @_;
    _reset_globals();
    $self->{verbose} = 1 if exists $p{verbose} and $p{verbose};
    my $entry_point;
    if (exists $p{entry_point}){
        $entry_point = $p{entry_point};
    }
    else{
        $entry_point = $self->{schema};
    }
    my $config = _make_config_template($self, $entry_point,0);
    return $config;
}


#################
# (internal) subs
#################

sub _reset_globals{
    my $self = shift;
    $self->{verbose} = undef;
    $self->{errors}
        = Data::Structure::Validation::Error::Collection->new();
}

# XXX bailout without "@parent_keys"
sub bailout ($$@) {
    my $self = shift;
    my $string = shift;
    my @parent_keys = @_;
    my $msg_parent_keys = join '->', @parent_keys;
    my (undef, undef, $line) = caller(0);
    my (undef, undef, undef, $sub) = caller(1);
    $self->{errors}->add(
        message => $string,
        path => $msg_parent_keys,
        caller => "$sub line $line"
    );
}

# this is not an object method because it is a helper sub for internal
# use and not a method that describes an object.
sub explain ($$) {
    my $self = shift;
    my $string = shift;
    # XXX enable multiple verbosity levels
    print $string if $self->{verbose};
}

# make template: recursive tree traversal
sub _make_config_template{
    my $self = shift;
    my $schema_section = shift;
    my $depth          = shift;

    my $config = {};

    for my $key (sort keys %{$schema_section}){

        # config keys always are hashes in schema.
        if (ref $schema_section->{$key} eq ref {} ){
            my $depth_add;
            if ($key eq 'members'){
                # "members" indicates children but is not written in config
                $depth_add = 0;
                return _make_config_template(
                    $self,
                    $schema_section->{$key},
                    $depth+$depth_add,
                );
            }
            else{
                $depth_add = 1;
                explain $self, ' ' x ($depth*4). "$key";

                if (exists $schema_section->{$key}->{description}){
                    explain $self, " => $schema_section->{$key}->{description}";
                    $config->{$key} = $schema_section->{$key}->{description}
                }

                if (exists $schema_section->{$key}->{value}){
                    explain $self, " $schema_section->{$key}->{value}";
                    $config->{$key} .= $schema_section->{$key}->{value};
                }
                explain $self, "\n";

                # we guess that if a section does not have a value
                # we might be interested in entering into it, too
                # Inversely, if there is a value, it is an end-point.
                if (! exists  $schema_section->{$key}->{value}){
                    $config->{$key} = _make_config_template(
                        $self,
                        $schema_section->{$key},
                        $depth+$depth_add,
                    );
                }
            }
        }
    }
    return $config;
}

# validate: recursive tree traversal
sub _validate{
    my $self = shift;
    # $(word)_section are *not* the data fields but the sections of the
    # config / schema the recursive algorithm is currently working on.
    # (Only) in the first call, these are identical.
    my $config_section = shift;
    my $schema_section = shift;
    my $depth          = shift // 0;
    my @parent_keys    = @_;

    for my $key (keys %{$config_section}){
        explain $self, ' ' x ($depth*4). "'$key'";
        # checks
        my $key_schema_to_descend_into =
            $self->__key_present_in_schema(
                $key, $config_section, $schema_section, @parent_keys
            );

        $self->__value_is_valid(
            $key, $config_section, $schema_section, $depth, @parent_keys
        );

        $self->__validator_returns_undef(
            $key, $config_section, $schema_section, $depth, @parent_keys
        ) if exists $schema_section->{$key}
             and exists $schema_section->{$key}->{validator};

        my $descend_into;
        if (exists  $schema_section->{$key}
                and $schema_section->{$key}->{no_descend_into}
                and $schema_section->{$key}->{no_descend_into}){
            explain $self, "skipping $key\n";
        }
        else{
            $descend_into = 1;
        }

        # recursion
        if ((ref $config_section->{$key} eq ref {})
                and $descend_into){
            explain $self, "'$key' is not a leaf and we descend into it\n";
            push @parent_keys, $key;
            $self->_validate(
                $config_section->{$key},
                $schema_section->{$key_schema_to_descend_into}->{members},
                $depth+1,
                @parent_keys
            );
            # to undo push before entering recursion.
            pop @parent_keys;
        }
        # Make sure that key in config is a leaf in schema.
        # We cannot descend into a non-existing branch in config
        # but it might be required by the schema.
        else {
            explain $self, "checking config key '$key' which is a leaf..";
            if ( $key_schema_to_descend_into
                    and
                 $schema_section->{$key_schema_to_descend_into}
                    and
                ref $schema_section->{$key_schema_to_descend_into} eq ref {}
                    and
                exists $schema_section->{$key_schema_to_descend_into}->{members}
            ){
                explain $self, "but schema requires members.\n";
                bailout $self, "'$key' should have members", @parent_keys;
            }
            else {
                explain $self, "schema key is also a leaf. ok.\n";
            }
        }
    }

    # look for missing mandatory keys in schema
    # this is only done on this level.
    # Otherwise "mandatory" inherited "upwards".
    $self->_check_mandatory_keys(
        $config_section, $schema_section, $depth, @parent_keys
    );
}



# called by _validate to check if a given key is defined in schema
sub __key_present_in_schema{
    my $self = shift;
    my $key            = shift;
    my $config_section = shift;
    my $schema_section = shift;
    my @parent_keys    = @_;

    my $key_schema_to_descend_into;

    # direct match: exact declaration
    if (exists $schema_section->{$key}){
        explain $self, " ok\n";
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
                explain $self, "'$key' matches $match_key\n";
                $key_schema_to_descend_into = $match_key;
            }
        }
    }

    # if $key_schema_to_descend_into is still undef we were unable to
    # match it against a key in the schema.
    unless ($key_schema_to_descend_into){
        explain $self, "$key not in schema, keys available: ";
        explain $self, "'$_' " for (keys %{$schema_section});
        explain $self, "\n";
        bailout $self, "key '$key' not found in schema\n", @parent_keys;
    }
    return $key_schema_to_descend_into
}

# called by _validate to check if a value is in line with definitions
# in the schema.
sub __value_is_valid{
    my $self = shift;
    my $key    = shift;
    my $config_section = shift;
    my $schema_section = shift;
    my $depth          = shift;
    my @parent_keys    = @_;

    if (exists  $schema_section->{$key}
            and $schema_section->{$key}->{value}){
        explain $self, ' 'x($depth*4). ref($schema_section->{$key}->{value})."\n";

        # currently, 2 type of restrictions are supported:
        # (callback) code and regex
        if (ref($schema_section->{$key}->{value}) eq 'CODE'){
            # possibly never implement this because of new "validator"
        }
        elsif (ref($schema_section->{$key}->{value}) eq 'Regexp'){
            explain $self, ' 'x($depth*4). "match '$config_section->{$key}' against '$schema_section->{$key}->{value}'";

            if ($config_section->{$key} =~ m/^$schema_section->{$key}->{value}$/){
                explain $self, " ok.\n"
            }
            else{
                # XXX never reach this?
                explain $self, " no.\n";
                bailout $self, "$config_section->{$key} does not match ^$schema_section->{$key}->{value}\$", @parent_keys;
            }
        }
        else{
            # XXX match literally? How much sense does this make?!
            # also, this is not tested

            explain $self, ' 'x($depth*4). "neither CODE nor Regexp\n";
            bailout $self, "'$key' not CODE nor Regexp", @parent_keys;
        }

    }
}

sub __validator_returns_undef {
    my $self = shift;
    my $key    = shift;
    my $config_section = shift;
    my $schema_section = shift;
    my $depth          = shift;
    my @parent_keys    = @_;
    explain $self, ' 'x($depth*4). "running validator for '$key': $config_section->{$key}\n";
    my $return_value = $schema_section->{$key}->{validator}->($config_section->{$key}, $config_section);
    if ($return_value){
        explain $self, ' 'x($depth*4)."validator error: $return_value\n";
        bailout $self, "Execution of validator for '$key' returns with error: $return_value", @parent_keys;
    }
    else {
        explain $self, ' 'x($depth*4). "successful validation for key '$key'\n";
    }
}

# check mandatory: look for mandatory fields in all hashes 1 level
# below current level (in schema)
# for each check if $config has a key.
sub _check_mandatory_keys{
    my $self = shift;
    my $config_section = shift;
    my $schema_section = shift;
    my $depth          = shift;
    my @parent_keys    = @_;

    for my $key (keys %{$schema_section}){
        explain $self, ' 'x($depth*4). "Checking if '$key' is mandatory: ";
        unless (exists $schema_section->{$key}->{optional}
                   and $schema_section->{$key}->{optional}){

            explain $self, "true\n";
            next if exists $config_section->{$key};

            # regex-keys never directly occur.
            if (exists $schema_section->{$key}->{regex}
                   and $schema_section->{$key}->{regex}){
                explain $self, ' 'x($depth*4)."regex enabled key found. ";
                explain $self, "Checking config keys.. ";
                my $c = 0;
                # look which keys match the regex
                for my $c_key (keys %{$config_section}){
                    $c++ if $c_key =~ /$key/;
                }
                explain $self, "$c matching occurencies found\n";
                next if $c > 0;
            }

            # should only get here in case of error.

            my $error_msg = '';
            $error_msg = $schema_section->{$key}->{error_msg}
                if exists $schema_section->{$key}->{error_msg};
            bailout $self, "mandatory key '$key' missing. Error msg: '$error_msg'",
                @parent_keys;
        }
        else{
            explain $self, "false\n";
        }
    }
}


=pod
=head1 NAME
Data::Structure::Validation - Validate a Perl Data Structure with a Schema

=head1 VERSION

version 0.0.0

=head1 SYNOPSIS

 use Data::Structure::Validation;
 my $schema = {
    section => {
        description => 'a section with a few members',
        error_msg   => 'cannot find "section" in config',
        members => {
            foo => {
                # value restriction either with a regex..
                value => qr{f.*},
                description => 'a string beginning with "f"'
            },
            bar => {
                # ..or with a validator callback.
                validator => sub {
                    my $self   = shift;
                    my $parent = shift;
                    # undef is "no-error" -> success.
                    return undef
                        if $self->{value} == 42;
                }
            },
            wuu => {
                optional => 1
            }
        }
    }
 };

 my $validator = Data::Structure::Validation->new($schema);

 my $config = {
    section => {
        foo => 'frobnicate',
        bar => 42,
        # "wuu" being optional can be omitted..
    }
 };

 my @errors = $validator->validate($config, verbose=>0);
 # no errors :-)


=head1 DESCRIPTION

Specify a schema as a hash of hashes. Describe your restrictions and verify a data structure against the schema.

=head2 Regex Enabled Keys
 animals => {
    # schema snip
    members => {
        'duck.*' => {
            regex => 1
        }
    }
 }

 # config snip
 animals => {
    duck     => 'ok',
    duckling => 'ok, too',
    miniduck => 'not ok'
 }

Regex enabled keys allow to define config keys that match a certain pattern.
This is useful if groups of similar members need to be present.
Unless such a key is optional at minimum one matching key in the configuration is required.



=head1 BUGS AND LIMITATIONS


=head1 AUTHOR
Matthias Bloch

=head1 LICENCE

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself. See perlartistic.


=cut
1;
