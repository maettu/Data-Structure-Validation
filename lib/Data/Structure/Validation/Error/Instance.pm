use 5.10.1;
use strict;
use warnings;
package Data::Structure::Validation::Error::Instance;

# an error.

sub new {
    my $class = shift;
    my %p     = @_;
    for (qw (message path caller)){
        $p{$_} // die "$_ missing";
    }

    my $self = {
        %p
    };
    bless ($self, $class);
    return $self;
}

1

