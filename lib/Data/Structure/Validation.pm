use 5.10.1;
use strict;
use warnings;
package Data::Structure::Validation;
use Data::Structure::Validation::Error::Collection;
# ABSTRACT: Validate a Perl Data Structure with a Schema
use Carp;

my $VERSION = '0.0.1';

##################
# (public) methods
##################

sub new{
    my $class  = shift;
    my $schema = shift || croak '$schema not supplied';
    my $verbose   = shift;

    # XXX think about making "parent" a parameter..

    my $self = {
        schema  => $schema,
        errors  => Data::Structure::Validation::Error::Collection->new(),
        verbose => $verbose,
        depth   => 0,
        indent  => 4, # how many spaces to indent in verbosity mode
        parent_keys  => ['root'],
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
    $self->_validate($config, $self->{schema}, 'root');
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

# XXX rename -> error
sub error {
    my $self = shift;
    my $string = shift;
    my $msg_parent_keys = join '->', @{$self->{parent_keys}};
    my (undef, undef, $line) = caller(0);
    my (undef, undef, undef, $sub) = caller(1);
    $self->{errors}->add(
        message => $string,
        path => $msg_parent_keys,
        caller => "$sub line $line"
    );
}

# explains what we are doing.
sub explain {
    my $self = shift;
    my $string = shift;
    my $indent = ' ' x ($self->{depth}*$self->{indent});
    $string =~ s/>>/$indent/;
    print $string if $self->{verbose};
}

# make template: recursive tree traversal
sub _make_config_template{
    my $self = shift;
    my $schema_section = shift;

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
                );
            }
            else{
                $depth_add = 1;
                $self->explain (">>$key");

                if (exists $schema_section->{$key}->{description}){
                    $self->explain (" => $schema_section->{$key}->{description}");
                    $config->{$key} = $schema_section->{$key}->{description}
                }

                if (exists $schema_section->{$key}->{value}){
                    $self->explain (" $schema_section->{$key}->{value}");
                    $config->{$key} .= $schema_section->{$key}->{value};
                }
                $self->explain ("\n");

                # we guess that if a section does not have a value
                # we might be interested in entering into it, too
                # Inversely, if there is a value, it is an end-point.
                if (! exists  $schema_section->{$key}->{value}){
                    $self->{depth}+=$depth_add;
                    $config->{$key} = _make_config_template(
                        $self,
                        $schema_section->{$key},
                    );
                    $self->{depth}-=$depth_add;
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

    for my $key (keys %{$config_section}){
        $self->explain (">>'$key'");
        # checks
        my $key_schema_to_descend_into =
            $self->__key_present_in_schema(
                $key, $config_section, $schema_section
            );

        $self->__value_is_valid(
            $key, $config_section, $schema_section
        );

        $self->__validator_returns_undef(
            $key, $config_section, $schema_section
        ) if exists $schema_section->{$key}
             and exists $schema_section->{$key}->{validator};

        my $descend_into;
        if (exists  $schema_section->{$key}
                and $schema_section->{$key}->{no_descend_into}
                and $schema_section->{$key}->{no_descend_into}){
            $self->explain (
                "skipping '$key' because schema explicitly says so.\n");
        }
        # skip config branch if schema key is empty.
        elsif (exists $schema_section->{$key}
                and ! %{$schema_section->{$key}}){
            $self->explain (
                "skipping '$key' because schema key is empty'");
        }
        elsif (exists $schema_section->{$key}
                and ! exists $schema_section->{$key}->{members}){
            $self->explain (
                "not descending into '$key'. No members specified\n"
            );
#~             use Data::Dumper; print Dumper $schema_section
        }
        else{
            $descend_into = 1;
            $self->explain (">>descending into '$key'\n");
        }

        # recursion
        if ((ref $config_section->{$key} eq ref {})
                and $descend_into){
            $self->explain (">>'$key' is not a leaf and we descend into it\n");
            push @{$self->{parent_keys}}, $key;
            $self->{depth}++;
            $self->_validate(
                $config_section->{$key},
                $schema_section->{$key_schema_to_descend_into}->{members}
            );
            # to undo push before entering recursion.
            pop @{$self->{parent_keys}};
            $self->{depth}--;
        }
        # Make sure that key in config is a leaf in schema.
        # We cannot descend into a non-existing branch in config
        # but it might be required by the schema.
        else {
            $self->explain(">>checking config key '$key' which is a leaf..");
            if ( $key_schema_to_descend_into
                    and
                 $schema_section->{$key_schema_to_descend_into}
                    and
                ref $schema_section->{$key_schema_to_descend_into} eq ref {}
                    and
                exists $schema_section->{$key_schema_to_descend_into}->{members}
            ){
                $self->explain("but schema requires members.\n");
                $self->error("'$key' should have members");
            }
            else {
                $self->explain("schema key is also a leaf. ok.\n");
            }
        }
    }

    # look for missing non-optional keys in schema
    # this is only done on this level.
    # Otherwise "mandatory" inherited "upwards".
    $self->_check_mandatory_keys(
        $config_section, $schema_section
    );
}



# called by _validate to check if a given key is defined in schema
sub __key_present_in_schema{
    my $self = shift;
    my $key            = shift;
    my $config_section = shift;
    my $schema_section = shift;

    my $key_schema_to_descend_into;

    # direct match: exact declaration
    if (exists $schema_section->{$key}){
        $self->explain(" ok\n");
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
                $self->explain("'$key' matches $match_key\n");
                $key_schema_to_descend_into = $match_key;
            }
        }
    }

    # if $key_schema_to_descend_into is still undef we were unable to
    # match it against a key in the schema.
    unless ($key_schema_to_descend_into){
        $self->explain(">>$key not in schema, keys available: ");
        $self->explain(join (", ", (keys %{$schema_section})));
        $self->explain("\n");
        $self->error("key '$key' not found in schema\n");
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

    if (exists  $schema_section->{$key}
            and $schema_section->{$key}->{value}){
        $self->explain('>>'.ref($schema_section->{$key}->{value})."\n");

        # currently, 2 type of restrictions are supported:
        # (callback) code and regex
        if (ref($schema_section->{$key}->{value}) eq 'CODE'){
            # possibly never implement this because of new "validator"
        }
        elsif (ref($schema_section->{$key}->{value}) eq 'Regexp'){
            $self->explain(">>match '$config_section->{$key}' against '$schema_section->{$key}->{value}'");

            if ($config_section->{$key} =~ m/^$schema_section->{$key}->{value}$/){
                $self->explain(" ok.\n");
            }
            else{
                # XXX never reach this?
                $self->explain(" no.\n");
                $self->error("$config_section->{$key} does not match ^$schema_section->{$key}->{value}\$");
            }
        }
        else{
            # XXX match literally? How much sense does this make?!
            # also, this is not tested

            $self->explain("neither CODE nor Regexp\n");
            $self->error("'$key' not CODE nor Regexp");
        }

    }
}

sub __validator_returns_undef {
    my $self = shift;
    my $key    = shift;
    my $config_section = shift;
    my $schema_section = shift;
    $self->explain("running validator for '$key': $config_section->{$key}\n");
    my $return_value = $schema_section->{$key}->{validator}->($config_section->{$key}, $config_section);
    if ($return_value){
        $self->explain("validator error: $return_value\n");
        $self->error("Execution of validator for '$key' returns with error: $return_value");
    }
    else {
        $self->explain("successful validation for key '$key'\n");
    }
}

# check mandatory: look for mandatory fields in all hashes 1 level
# below current level (in schema)
# for each check if $config has a key.
sub _check_mandatory_keys{
    my $self = shift;
    my $config_section = shift;
    my $schema_section = shift;

    for my $key (keys %{$schema_section}){
        $self->explain(">>Checking if '$key' is mandatory: ");
        unless (exists $schema_section->{$key}->{optional}
                   and $schema_section->{$key}->{optional}){

            $self->explain("true\n");
            next if exists $config_section->{$key};

            # regex-keys never directly occur.
            if (exists $schema_section->{$key}->{regex}
                   and $schema_section->{$key}->{regex}){
                $self->explain(">>regex enabled key found. ");
                $self->explain("Checking config keys.. ");
                my $c = 0;
                # look which keys match the regex
                for my $c_key (keys %{$config_section}){
                    $c++ if $c_key =~ /$key/;
                }
                $self->explain("$c matching occurencies found\n");
                next if $c > 0;
            }

            # should only get here in case of error.

            my $error_msg = '';
            $error_msg = $schema_section->{$key}->{error_msg}
                if exists $schema_section->{$key}->{error_msg};
            $self->error("mandatory key '$key' missing. Error msg: '$error_msg'");
        }
        else{
            $self->explain("false\n");
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
