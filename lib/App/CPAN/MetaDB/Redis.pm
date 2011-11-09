package App::CPAN::MetaDB::Redis;

use strict;
use warnings;

use Redis;

sub new {

    my($class, %opts) = @_;

	return bless {
		db => Redis->new(server => $opts{server})
	}, $class;

}

sub find_package {
	my($self, $package_name) = @_;

	return $self->{db}->get($package_name);
}

sub update_package {

	my($self, %data) = @_;

	$self->{db}->set( 
		$data{name} => 
			sprintf "---\ndistfile: %s\nversion: %s\n",
                $data{path},
                $data{version}
	);

}

1;
