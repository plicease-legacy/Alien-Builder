use strict;
use warnings;
use Test::More;
use Alien::Builder::Download::Plugin::HTTPTiny;
use URI;
use File::Temp qw( tempdir );
use HTTP::Tiny;

# set ALIEN_BUILDER_LIVE_TEST to an integer pair of ports
# separated by a colon.  The first port is for http and
# the second is for ftp.  Then run corpus/server.pl, this
# will start the FTP and HTTP servers that this test
# can use.

plan skip_all => 'test requires Perl 5.10 or better' if $] < 5.010;
plan skip_all => 'live test, set ALIEN_BUILDER_LIVE_TEST'
  unless $ENV{ALIEN_BUILDER_LIVE_TEST};
my($port) = split /:/, $ENV{ALIEN_BUILDER_LIVE_TEST};

plan tests => 3;

my $base_uri = URI->new("http://localhost");
$base_uri->port($port);

subtest listing => sub {

  plan tests => 2;

  my %tests = (
    'with trailing slash'    => URI->new_abs("/file/repo/", $base_uri),
    'without trailing slash' => URI->new_abs("/file/repo", $base_uri),
  );

  foreach my $test_name (keys %tests) {
    my $uri = $tests{$test_name};

    subtest $test_name => sub {
      plan tests => 6;

      my $download = Alien::Builder::Download::Plugin::HTTPTiny->get($uri);
      isa_ok $download, 'Alien::Builder::Download::List';
      
      note " + $_ => @{[ $download->uri_for($_) ]}" for $download->list;
      
      is_deeply [grep /\.tar\.gz$/, $download->list], [qw( bar-1.00.tar.gz foo-1.00.tar.gz hello-1.00.tar.gz hello-1.02.tar.gz )], 'list matches';

      foreach my $uri (map { $download->uri_for($_) } grep /\.tar\.gz$/, $download->list)
      {
        my $res = HTTP::Tiny->new->head($uri);
        ok $res->{success}, "HEAD $uri";
      }

    };
  }

};

subtest file => sub {

  my $uri = $base_uri->clone;
  $uri->path('/file/repo/hello-1.00.tar.gz');

  my $download = Alien::Builder::Download::Plugin::HTTPTiny->get($uri);
  
  isa_ok $download, 'Alien::Builder::Download::File';
  
  my $filename = $download->copy_to(tempdir( CLEANUP => 1 ));

  ok -f $filename, "filename: $filename";
  ok -s $filename, "is not zero";

};

subtest 'not found' => sub {

  my $uri = $base_uri->clone;
  $uri->path('/file/repo/bogus');
  
  eval { Alien::Builder::Download::Plugin::HTTPTiny->get($uri) };

  like $@, qr{^failed downloading http://localhost:[0-9]+/file/repo/bogus 404 Not Found}, 'diagnostic';

};
