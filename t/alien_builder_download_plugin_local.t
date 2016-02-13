use strict;
use warnings;
use Test::More tests => 3;
use Alien::Builder::Download::Plugin::Local;
use URI::file;

my @files = qw( bar-1.00.tar.gz foo-1.00.tar.gz hello-1.00.tar.gz hello-1.02.tar.gz );

subtest protocols => sub {
  plan tests => 1;
  
  is_deeply [Alien::Builder::Download::Plugin::Local->protocols], [qw( file )], 'only file';
};

subtest dir => sub {

  plan tests => 2;

  my %tests = (
    'with trailing slash'    => URI::file->new_abs("./corpus/file/repo/"),
    'without trailing slash' => URI::file->new_abs("./corpus/file/repo"),
  );

  foreach my $test_name (keys %tests) {
    my $uri = $tests{$test_name};

    subtest $test_name => sub {
      plan tests => 7;
  
      ok $uri, "uri = $uri";

      my $download = Alien::Builder::Download::Plugin::Local->get($uri);
      isa_ok $download, 'Alien::Builder::Download::List';

      is_deeply [$download->list], \@files, 'correct download list';
    
      foreach my $file (@files)
     {
        subtest "uri for $file" => sub {
           plan tests => 3;
          my $uri = $download->uri_for($file);
          isa_ok $uri, 'URI';
          is $uri->scheme, 'file', "URI is file: $uri";
          ok -f $uri->file, "is a file @{[ $uri->file ]}";
        };
      }
      
    };
  }
};


subtest file => sub {
  plan tests => 3;

  my $download = Alien::Builder::Download::Plugin::Local->get(URI::file->new_abs("./corpus/file/repo/hello-1.00.tar.gz"));
  isa_ok $download, 'Alien::Builder::Download::File';
  
  my $filename = $download->_localfile;
  
  ok -f $filename, "filename: $filename";
  ok -s $filename, "is not zero";

};
