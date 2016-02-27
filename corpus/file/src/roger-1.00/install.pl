use strict;
use warnings;
use if $] >= '5.010001', 'autodie';
use File::Spec;
use File::Path qw( mkpath );

my $prefix = shift @ARGV;
die "no prefix given!"  unless $prefix;

open my $fh, '>', 'install.txt';
print $fh "install data";
close $fh;

my $dir = File::Spec->catdir($prefix, 'lib', 'pkgconfig');
my $file = File::Spec->catfile($dir, 'roger.pc');

mkpath $dir, 0, 0700;
open $fh, '>', $file;
print $fh <<EOF;
Name: roger
Libs: -L/opt/roger/lib -lroger
Cflags: -I/opt/roger/include
EOF
close $fh;
