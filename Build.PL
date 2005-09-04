use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'X11::Muralis',
    license             => 'perl',
    dist_author         => 'Kathryn Andersen',
    dist_version_from   => 'lib/X11/Muralis.pm',
	requires            => {
	     'Image::Info' => 0,
	'Getopt::Long' => 2.34,
	'Pod::Usage' => 0,
	'Getopt::ArgvFile' => 1.09,
	},
    build_requires => {
        'Test::More' => 0,
    },
#    add_to_cleanup      => [ 'X11-Muralis-*' ],
script_files => [qw(scripts/muralis)],

);

$builder->create_build_script();

# create the Makefile.PL
use Module::Build::Compat;
print "creating Makefile.PL\n";
Module::Build::Compat->create_makefile_pl('passthrough', $builder);
