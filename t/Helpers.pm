#!/usr/bin/perl
package t::Helpers;
sub any_error_contains {
    my $string = shift;
    my $field  = shift;
    my @errors = @_;
    for my $error (@errors){
        return 1 if $error->{$field} =~ /$string/;
    }
    return undef;
}


1

