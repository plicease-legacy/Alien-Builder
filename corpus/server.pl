use strict;
use warnings;
use File::Which qw( which );

if($] < 5.010)
{
  exit;
}

die "set ALIEN_BUILDER_LIVE_TEST" unless defined $ENV{ALIEN_BUILDER_LIVE_TEST};

my($http_port, $ftp_port) = split /:/, $ENV{ALIEN_BUILDER_LIVE_TEST};

my $http_this = which 'http_this';
my $exit = 0;

if($http_this)
{
  unless(fork)
  {
    open STDOUT, '>', '/dev/null';
    open STDERR, '>', '/dev/null';
    exec 'http_this', '--port' => $http_port, 'corpus';
  }
}
else
{
  $exit = 1;
  warn "unable to find http_this";
}

unless(fork)
{
  require AnyEvent;
  require AnyEvent::FTP::Server;
  my $server = AnyEvent::FTP::Server->new(
    hostname        => '127.0.0.1',
    port            => $ftp_port,
    inet            => 0,
    default_context => 'AnyEvent::FTP::Server::Context::FSRO',
  );
  
  $server->on_connect(sub {
    my($con) = @_;
    $con->context->authenticator(sub {
      my($name, $pass) = @_;
      return !!($name =~ /^(ftp|anonymous)$/);
    });
  });
  
  $server->start;
  
  AnyEvent->condvar->recv;
  
}

exit $exit;
