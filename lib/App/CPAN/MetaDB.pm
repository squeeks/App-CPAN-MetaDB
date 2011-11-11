package App::CPAN::MetaDB;

=head1 NAME

App::CPAN::MetaDB - Provide CPAN metadata for cpanminus clients

=head1 VERSION

Version 0.03

=cut

our $VERSION = '0.03';

=head1 SYNOPSIS

This is a L<Plack> application that grabs CPAN metadata and serves it to
L<cpanminus> clients. You can serve cpanminus clients by creating a C<app.psgi> 
application:

    #!/usr/bin/env plackup

    use strict;
    use warnings;

    use Plack::Builder;

    use App::CPAN::MetaDB;
    use App::CPAN::MetaDB::Memcached;

    my $metadb = App::CPAN::MetaDB->new(
        mirror  => 'http://cpan.cpantesters.org', # use the most suitable (fast) mirror
        storage => App::CPAN::MetaDB::Memcached->new({
            servers => ['127.0.0.1:11211']
        })
    );

    builder {
        mount "/" => $metadb->app;
    }


=cut

use 5.008;
use strict;
use warnings;

use IO::Uncompress::Gunzip 'gunzip';
use YAML;
use JSON qw/from_json/;
use LWP::UserAgent;

my %meta;

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
        my $data = $meta{storage}->_find_package($package);
        if($data) {
            $response = $data;
        } else {
            $data = _fetch_metacpan(undef, $package);
            if($data) {
                $meta{storage}->_update_package(%{$data});
                $response = sprintf "---\ndistfile: %s\nversion: %s\n",
                    $data->{path},
                    $data->{version};
            } else {
                $status   = 404;
                $response = "";
            }
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

=item * storage

The storage engine you wish to use, along with any required arguments.

=back

=cut
sub new {
    my($class, %opts) = @_;
    %meta = %opts;
    $meta{ua} = LWP::UserAgent->new;
    return bless {}, $class;
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
    my $response = $meta{ua}->get($meta{mirror}."/modules/02packages.details.txt.gz");
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
        $meta{storage}->_update_package(
            name    => $name,
            version => $version,
            path    => $path
        );
    }

}

=head2 fetch_recent

Grabs metadata from the mirror containing the changes from the past day or so.

=cut
sub fetch_recent {
    my($self) = shift;

    my $response = $meta{ua}->get($meta{mirror}."/authors/RECENT-1d.yaml");
    if (!$response->is_success) {
        #TODO Logging
        return undef;
    }

    my $yaml;
    eval { $yaml = Load($response->content); };

    if(!$yaml || $@) {
        return undef;
    }

    for my $recent(@{$yaml->{recent}}) {
        next if($recent->{path} !~/\.tar\.gz$/);
        $recent->{path} =~s!^id/!!;
        my @dist = split '-', (split '/', $recent->{path})[-1];
        $dist[-1] =~s/\.tar\.gz$//;
        $recent->{version} = pop @dist;
        $recent->{name}    = join '::', @dist;

        $meta{storage}->_update_package(
            name    => $recent->{name},
            version => $recent->{version},
            path    => $recent->{path}
        );
    }

}

sub _fetch_metacpan {
    my($self, $dist) = @_;
    
    $dist=~s/::/-/g;
    
    my $response = $meta{ua}->get("http://api.metacpan.org/release/".$dist);
    if (!$response->is_success) {
        #TODO Logging
        return undef;
    }

    my $json;
    eval { $json = from_json($response->content); };
    if(!$json || $@) {
        return undef;
    }

    ($json->{path}) = $json->{download_url} =~/^.*id\/(.*)$/;
    $json->{distribution} =~s/-/::/;

    return {
        name    => $json->{distribution},
        version => $json->{version},
        path    => $json->{path}
    };

}

=head1 AUTHOR

Squeeks, C<< <squeek at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-app-cpan-metadb at
rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=App-CPAN-MetaDB>.  I will be
notified, and then you'll automatically be notified of progress on your bug as
I make changes.

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

Tatsuhiko Miyagawa for L<App::cpanminus>.

=head1 LICENSE AND COPYRIGHT

Copyright 2011 Squeeks.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of App::CPAN::MetaDB

__DATA__

<!DOCTYPE HTML>
<html lang="en">
<head>
<meta charset="utf-8">
<title>CPAN Meta DB</title>
<link rel="stylesheet" href="http://miyagawa.github.com/screen.css">
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
This is yet another CPAN Meta DB, created by Squeeks. Thanks, miyagawa.
</div>

</div>
</body>
</html>

