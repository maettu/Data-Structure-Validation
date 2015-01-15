use 5.10.1;
use strict;
use warnings;
package Data::Structure::Validation::Error::Collection;
use Data::Structure::Validation::Error::Instance;

# Organise errors for Data::Structure::Validation

sub new {
    my $class = shift;
    my $self = {
        errors => [] # the error instances are going into here
    };
    bless ($self, $class);
    return $self;
}

sub add {
    my $self = shift;
    my %p    = @_;
    my $error = Data::Structure::Validation::Error::Instance->new(%p);
    push @{$self->{errors}}, $error;
}

sub as_array{
    my $self = shift;
#~     use Data::Dumper; print Dumper $self->{errors};
    return @{$self->{errors}};
}
1
