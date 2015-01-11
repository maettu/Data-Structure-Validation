use 5.10.1;
use strict;
use warnings;
package Data::Structure::Validation::Error::Instance;

use overload ('""' => \&stringify);

# an error.

sub new {
    my $class = shift;
    my $self = { @_ };
    my %keys  = ( map { $_ => 1 } keys %$self );
    for (qw (message path caller)){
        delete $keys{$_};
        $self->{$_} // die "$_ missing";
    }
    die "Unknown keys ".join(",",keys %keys) if keys %keys;
    bless ($self, $class);
    return $self;
}

sub stringify {
    my $self = shift;
    return $self->{path}.": ".$self->{message};
}
1;

