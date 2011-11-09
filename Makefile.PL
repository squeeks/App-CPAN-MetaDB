use 5.008;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'App::CPAN::MetaDB',
    AUTHOR              => q{Squeeks <squeek@cpan.org>},
    VERSION_FROM        => 'lib/App/CPAN/MetaDB.pm',
    ABSTRACT_FROM       => 'lib/App/CPAN/MetaDB.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More'             => 0,
        'Plack'                  => 0.99,
        'IO::Uncompress::Gunzip' => 0,
        'LWP::UserAgent'         => 0,
		'Redis'					 => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'App-CPAN-MetaDB-*' },
);
