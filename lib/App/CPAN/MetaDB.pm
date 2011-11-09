package App::CPAN::MetaDB;

=head1 NAME

App::CPAN::MetaDB - Provide CPAN metadata for cpanminus clients

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

This is a L<Plack> application that grabs CPAN metadata and serves it to
L<cpanminus> clients. 

=cut

use 5.008;
use strict;
use warnings;

use IO::Uncompress::Gunzip 'gunzip';
use LWP::UserAgent;

use App::CPAN::MetaDB::Redis;

my %config;
my $db;

my $app = sub {
    my $env = shift;

    my $response;
    my $status  = 200;
    my $content = 'text/x-yaml';

    if($env->{PATH_INFO} eq '/'){
        $content  = 'text/html';
        $response = do { local $/; <DATA> };

    } elsif($env->{PATH_INFO} =~/v([0-9\.]+)\/package\/(.*)/) {
        my ($version, $package) = $env->{PATH_INFO} =~/v([0-9\.]+)\/package\/(.*)/;
        my $data = $db->_find_package($package);
        if($data) {
            $response = $data;
        } else {
            $status   = 404;
            $response = "";
        }
    } else {
        $status   = 404;
        $response = "404 not found";
    }

    [ $status, [ "Content-Type", $content ], [ $response ] ];
};

=head1 METHODS

=head2 new(%opts)

Creates a new object. The following arguments will be required:

=over

=item * mirror

The CPAN mirror to fetch the metadata from. This should not be a L<CPAN::Mini>
mirror unless you explicitly fetching /modules/02packages.details.txt.gz in your
C<.minicpanrc>.

=back

=cut
sub new {
    my($class, %opts) = @_;
    %config = %opts;
    $db = App::CPAN::MetaDB::Redis->new(%{$config{db}});
    return bless {
        ua => LWP::UserAgent->new,
    }, $class;
}

=head2 app

Returns a code reference - this is the Plack C<$app> that is passed along.

=cut
sub app {
    return $app;
}

=head2 fetch_packages

Fetches, parses and stores the package list from the defined CPAN Mirror. This
is a memory consuming task - careful with its use in memory constrained
environments.

=cut
sub fetch_packages {
    my $self = shift;

    my $decompressed;
    my @packages;
    my $response = $self->{ua}->get($config{mirror}."/modules/02packages.details.txt.gz");
    if ($response->is_success) {
        gunzip \$response->content => \$decompressed;
    } else {
        #TODO Logging?
    }

    if($decompressed) {
        @packages = split '\n', $decompressed;
    } else {

    }

    # First 9 or so lines are header information...
    foreach (10..$#packages) {
        my($name, $version, $path) = split /\s+/, $packages[$_];
        $self->{db}->_update_package(
            name    => $name,
            version => $version,
            path    => $path
        );
    }

}

=head1 AUTHOR

Squeeks, C<< <squeek at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-app-cpan-metadb at
rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=App-CPAN-MetaDB>.  I will be
notified, and then you'll automatically be notified of progress on your bug as I
make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc App::CPAN::MetaDB

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=App-CPAN-MetaDB>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/App-CPAN-MetaDB>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/App-CPAN-MetaDB>

=item * Search CPAN

L<http://search.cpan.org/dist/App-CPAN-MetaDB/>

=back


=head1 ACKNOWLEDGEMENTS

Tatsuhiko Miyagawa for L<cpanminus>.

=head1 LICENSE AND COPYRIGHT

Copyright 2011 Squeeks.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of App::CPAN::MetaDB

__DATA__

<html>
<head>
<title>CPAN Meta DB</title>
<link rel="stylesheet" href="http://miyagawa.github.com/screen.css" ?>
<style>
body { font-size: 1.1em }
.info { font-size: 0.9em }
#footer { margin-top: 100px; font-size: 0.8em; text-align: center }
</style>
</head>
<body>
<div class="container">
<h1>CPAN Meta DB</h1>

<p class="info">
This is (yet another) CPAN metadata database that provides REST API for the CPAN
distributions, intended to be used by CPAN clients such as <a
href="http://github.com/miyagawa/cpanminus">cpanminus</a>. Currently the only
implemented endpoint is the resolver to get distribution file names from package
names (a.k.a <code>02packages.details.txt.gz</code>) but there's a plan to
implement more to extract information from <code>META.yml</code> etc. See also
<a href="http://search.cpan.org/perldoc?CPANDB">CPANDB</a> and <a
href="http://search.cpan.org/perldoc?App::CPANIDX">CPANIDX</a> for the similar
works.
</p>

<h2>APIs</h2>

<dl>
<dt><code>/v1.0/package/Package::Name</code><dt>
<dd>Returns the latest distribution file path that contains the package and its
version string ('undef' is a valid version string) in YAML format. Returns 404
status code if the package is not found.</dd>
</dl>

<div id="footer">
This is yet another CPAN Meta DB, created by Squeeks. Thanks, miyagawa.</a>.
</div>

</div>
</body>
</html>

