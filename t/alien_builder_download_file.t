use strict;
use warnings;
use Test::More tests => 2;
use File::Temp qw( tempdir );
use Alien::Builder::Download::File;

subtest localfile => sub {
  plan tests => 4;

  my $original_filename = 'corpus/file/repo1/hello-1.00.tar.gz';
  my $content = do {
    open my $fh, '<', $original_filename;
    local $/;
    <$fh>;
  };

  my $download = Alien::Builder::Download::File->new(
    localfile => $original_filename,
    filename  => 'hello-1.00.tar.gz',
  );

  my $filename = $download->copy_to(tempdir(CLEANUP=>1));
  
  ok -f $filename, "file: $filename";
  ok -s $filename, 'is not zero size';

  my $actual = do {
    open my $fh, '<', $filename;
    local $/;
    <$fh>;
  };
  
  is $actual, $content, 'content matches';
  
  is $download->is_file, 1, 'is_file';
};

subtest content => sub {
  plan tests => 4;

  my $content = 'abcdefg';

  my $download = Alien::Builder::Download::File->new(
    content => $content,
    filename => 'foo.txt',
  );
  
  my $filename = $download->copy_to(tempdir(CLEANUP=>1));
  
  ok -f $filename, "file: $filename";
  ok -s $filename, 'is not zero size';

  my $actual = do {
    open my $fh, '<', $filename;
    local $/;
    <$fh>;
  };
  
  is $actual, $content, 'content matches';

  is $download->is_file, 1, 'is_file';
};
