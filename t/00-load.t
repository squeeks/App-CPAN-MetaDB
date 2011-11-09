#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'App::CPAN::MetaDB' ) || print "Bail out!\n";
}

diag( "Testing App::CPAN::MetaDB $App::CPAN::MetaDB::VERSION, Perl $], $^X" );
