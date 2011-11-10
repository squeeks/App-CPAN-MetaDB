package App::CPAN::MetaDB::Redis;

=head1 NAME

App::CPAN::MetaDB::Redis

=head1 SYNOPSIS

This provides the interface to store and retrieve data from the specified
L<Redis> database.

=cut

use strict;
use warnings;

use Redis;
=head1 CONSTRUCTION

=head2 new

Requires you supply a hash with the "server" key pointing to the appropriate
server:port. You can also add in other keys that L<Redis>->new will accept.

=cut
sub new {

    my($class, %opts) = @_;

    return bless {
        db => Redis->new(%opts)
    }, $class;

}

sub _find_package {
    my($self, $package_name) = @_;

    return $self->{db}->get($package_name);
}

sub _update_package {

    my($self, %data) = @_;

    $self->{db}->set( 
        $data{name} => 
            sprintf "---\ndistfile: %s\nversion: %s\n",
                $data{path},
                $data{version}
    );

}

=head1 SEE ALSO

L<App::CPAN::MetaDB>

=cut

1;
