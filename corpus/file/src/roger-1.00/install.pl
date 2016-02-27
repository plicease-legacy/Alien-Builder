use strict;
use warnings;
use if $] >= '5.010001', 'autodie';
use File::Spec;
use File::Path qw( mkpath );
use File::Copy qw( move );

my $prefix = shift @ARGV;
die "no prefix given!"  unless $prefix;

do {
  open my $fh, '>', 'install.txt';
  print $fh "install data";
  close $fh;
};

do {
  my $dir = File::Spec->catdir($prefix, 'lib', 'pkgconfig');
  my $file = File::Spec->catfile($dir, 'roger.pc');

  mkpath $dir, 0, 0700;
  open my $fh, '>', $file;
  print $fh <<EOF;
Name: roger
Libs: -L/opt/roger/lib -lroger
Cflags: -I/opt/roger/include
EOF
  close $fh;

};

do {

  my $dir = File::Spec->catdir($prefix, 'lib');

  mkpath $dir, 0, 0700;
  
  foreach my $file (map { File::Spec->catfile($dir,$_) } qw( libroger.a libroger.so ))
  {
    open my $fh, '>', $file;
    close $fh;
  }
};

do {

  my $dir = File::Spec->catdir($prefix, 'include');
  
  mkpath $dir, 0, 0700;
  my $file = File::Spec->catfile($dir, 'roger.h');
  open my $fh, '>', $file;
  close $fh;

};
