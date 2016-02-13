use strict;
use warnings;
use Test::More;
use Alien::Builder::Download::Plugin::NetFTP;
use URI;
use URI::file;

# set ALIEN_BUILDER_LIVE_TEST to an integer pair of ports
# separated by a colon.  The first port is for http and
# the second is for ftp.  Then run corpus/server.pl, this
# will start the FTP and HTTP servers that this test
# can use.

plan skip_all => 'live test, set ALIEN_BUILDER_LIVE_TEST'
  unless $ENV{ALIEN_BUILDER_LIVE_TEST};
my(undef, $port) = split /:/, $ENV{ALIEN_BUILDER_LIVE_TEST};

plan tests => 2;

my $base_uri = URI::file->new_abs('./corpus/');
$base_uri->scheme('ftp');
$base_uri->host('127.0.0.1');
$base_uri->port($port);

subtest listing => sub {

  plan tests => 2;

  my %tests = (
    'with trailing slash'    => URI->new_abs("file/repo/", $base_uri),
    'without trailing slash' => URI->new_abs("file/repo", $base_uri),
  );
  
  foreach my $test_name (keys %tests) {
  
    my $uri = $tests{$test_name};

    subtest $test_name => sub {
      plan tests => 7;
      ok $uri, "uri: $uri";
      
      my $download = Alien::Builder::Download::Plugin::NetFTP->get($uri);
      isa_ok $download, 'Alien::Builder::Download::List';

      note "+ $_" for $download->list;
 
      is_deeply [$download->list], [qw( bar-1.00.tar.gz foo-1.00.tar.gz hello-1.00.tar.gz hello-1.02.tar.gz )], 'list matches';

      foreach my $url (map { $download->uri_for($_) } $download->list)
      {
        subtest "download $url" => sub {
          plan tests => 3;
          my $download2 = Alien::Builder::Download::Plugin::NetFTP->get($url);
          isa_ok $download2, 'Alien::Builder::Download::File';
          ok -f $download2->_localfile, "localfile: @{[ $download2->_localfile ]}";
          ok $download2->_filename, "filename: @{[ $download2->_filename ]}";
        };
      }

    };
  }

};

subtest file => sub {
  plan tests => 4;

  my $uri = URI->new_abs("file/repo/hello-1.00.tar.gz", $base_uri);
  
  my $download = Alien::Builder::Download::Plugin::NetFTP->get($uri);
  isa_ok $download, 'Alien::Builder::Download::File';

  ok -f $download->_localfile, "localfile: @{[ $download->_localfile ]}";
  ok -s $download->_localfile, "is not size zero";
  ok $download->_filename, "filename: @{[ $download->_filename ]}";

};

