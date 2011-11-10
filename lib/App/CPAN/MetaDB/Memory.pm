package App::CPAN::MetaDB::Memory;

=head1 NAME

App::CPAN::MetaDB::Memory - stash data in memory.

=head1 SYNOPSIS

This provides the interface to store the CPAN metadata in memory. This is
clearly not persistent, and it's going to consume an amount of memory that in
constrained environments may not be a good idea.

=cut

use strict;
use warnings;

my %dists;

=head1 CONSTRUCTION

=head2 new

=cut
sub new {
    my($class) = @_;
    return bless {}, $class;
}

sub _find_package {
    my($self, $package_name) = @_;
    return $dists{$package_name} || undef;
}

sub _update_package {

    my($self, %data) = @_;

    $dists{$data{name}} =
        sprintf "---\ndistfile: %s\nversion: %s\n",
			$data{path},
			$data{version};
}

=head1 SEE ALSO

L<App::CPAN::MetaDB>

=cut

1;

