use strict;
use warnings;
use Test::More tests => 2;
use Alien::Builder::Download;
use URI::file;

delete $ENV{ALIEN_BUILDER_DOWNLOAD_PLUGINS};

subtest choose => sub {

  my $first;
  my $second;

  ($first, $second) = Alien::Builder::Download->_choose("file://localhost/foo/bar/baz.txt");

  is_deeply [$first,$second], [qw( Alien::Builder::Download::Plugin::LWP Alien::Builder::Download::Plugin::Local )], 'file';

  ($first, $second) = Alien::Builder::Download->_choose("http://localhost/foo/bar/baz.txt");

  is_deeply [$first,$second], [qw( Alien::Builder::Download::Plugin::LWP Alien::Builder::Download::Plugin::HTTPTiny )], 'http';

  ($first, $second) = Alien::Builder::Download->_choose("ftp://localhost/foo/bar/baz.txt");

  is_deeply [$first,$second], [qw( Alien::Builder::Download::Plugin::LWP Alien::Builder::Download::Plugin::NetFTP )], 'ftp';

};

subtest get => sub {

  my $uri = URI::file->new_abs('./corpus/file/repo/hello-1.00.tar.gz');
  my $download = Alien::Builder::Download->get($uri);
  
  isa_ok $download, 'Alien::Builder::Download::File';
  ok -f $download->_localfile, "file: @{[ $download->_localfile ]}";
  ok -s $download->_localfile, "size is larger than zero";

};

package
  Alien::Builder::Download::Plugin::LWP;

sub protocols { qw( file http https ftp ) }
