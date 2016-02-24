use strict;
use warnings;
use Test::More tests => 3;
use URI::file;
use Alien::Builder::Download::Plugin::Local;
use Alien::Builder::Extractor::Plugin::ArchiveTar;
use File::Temp qw( tempdir );

subtest normal => sub {
  plan tests => 3;

  my $download = Alien::Builder::Download::Plugin::Local->get(
    URI::file->new_abs('corpus/file/repo1/hello-1.00.tar.gz')
  );
  
  my $dir = tempdir( CLEANUP => 1 );
  my $root = Alien::Builder::Extractor::Plugin::ArchiveTar->extract(
    $download->copy_to($dir) => $dir,
  );
  
  ok -d $root, "root = $root";
  
  my $file = File::Spec->catfile($root, 'hello.sh');
  ok -f $file, "has $file";
  ok -s $file, "is not zero size";

};

subtest 'with bogus symlink' => sub {
  plan tests => 3;

  my $download = Alien::Builder::Download::Plugin::Local->get(
    URI::file->new_abs('corpus/file/repo1/hello-1.02.tar.gz')
  );
  
  my $dir = tempdir( CLEANUP => 1 );
  my $root = eval { 
    Alien::Builder::Extractor::Plugin::ArchiveTar->extract(
      $download->copy_to($dir) => $dir,
    );
  };
  diag $@ if $@;
  
  ok -d $root, "root = $root";
  
  my $file = File::Spec->catfile($root, 'hello.sh');
  ok -f $file, "has $file";
  ok -s $file, "is not zero size";

};

subtest 'with files in root' => sub {
  plan tests => 7;

  my $download = Alien::Builder::Download::Plugin::Local->get(
    URI::file->new_abs('corpus/file/repo1/bar-1.00.tar.gz')
  );
  
  my $dir = tempdir( CLEANUP => 1 );
  my $root = Alien::Builder::Extractor::Plugin::ArchiveTar->extract(
    $download->copy_to($dir) => $dir,
  );
  
  ok -d $root, "root = $root";
  
  my $file = File::Spec->catfile($root, 'hello.sh');
  ok -f $file, "has $file";
  ok -s $file, "is not zero size";

  $file = File::Spec->catfile($root, 'README.txt');
  ok -f $file, "has $file";
  ok -s $file, "is not zero size";

  $file = File::Spec->catfile($root, 'Makefile');
  ok -f $file, "has $file";
  ok -z $file, "is zero size";

};
