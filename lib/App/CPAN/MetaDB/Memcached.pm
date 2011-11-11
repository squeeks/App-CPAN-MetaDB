package App::CPAN::MetaDB::Memcached;

=head1 NAME

App::CPAN::MetaDB::Memcached - Store metadata in memcached

=head1 SYNOPSIS

This provides the interface to store and retrieve data from memcached servers,
using L<Cache::Memcached::Fast>.

=cut

use strict;
use warnings;

use Cache::Memcached::Fast;

=head1 CONSTRUCTION

=head2 new

Settings should be supplied as a hash ref matching that of
L<Cache::Memcached::Fast->new()>.

=cut
sub new {

    my($class, $opts) = @_;

    return bless {
        memcached => Cache::Memcached::Fast->new($opts)
    }, $class;

}

sub _find_package {
    my($self, $package_name) = @_;

    return $self->{memcached}->get($package_name);
}

sub _update_package {

    my($self, %data) = @_;

    $self->{memcached}->set( 
        $data{name},
            sprintf "---\ndistfile: %s\nversion: %s\n",
                $data{path},
                $data{version}
    );

}

=head1 SEE ALSO

L<App::CPAN::MetaDB>

=cut

1;

