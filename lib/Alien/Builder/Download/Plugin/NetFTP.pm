package Alien::Builder::Download::Plugin::NetFTP;

use strict;
use warnings;
use Net::FTP;
use File::Temp qw( tempdir );
use File::Spec;
use Carp qw( croak );
use File::Spec;
use File::Spec::Unix;
use URI;

# ABSTRACT: FTP downloader using Net::FTP
# VERSION

=head1 METHODS

=head2 get

=cut

sub get
{
  my(undef, $uri) = @_;
  
  # this will either convert $uri into a URI object
  # or clone an existing one so that we can make
  # changes if needed
  $uri = URI->new($uri);
  
  croak "only works with ftp URL" unless $uri->scheme eq 'ftp';
  
  my $ftp = Net::FTP->new($uri->host, Port => $uri->port)
    || die "unable to connect to $uri";
  $ftp->login($uri->user, $uri->password)
    || die "unable to login to $uri";

  my $localfile = File::Spec->catfile( tempdir( CLEANUP => 1 ), 'data' );
  
  if(my $localfile = $ftp->get($uri->path, File::Spec->catfile( tempdir( CLEANUP => 1 ), 'data' )))
  {
    my(undef,undef,$filename) = File::Spec::Unix->splitpath($uri->path);
    require Alien::Builder::Download::File;
    my $file = Alien::Builder::Download::File->new(
      localfile => $localfile,
      filename  => $filename,
      move      => 1,
    );
  }
  elsif($ftp->cwd($uri->path))
  {
    $uri->path($uri->path . '/') unless $uri->path =~ m{/$};
    require Alien::Builder::Download::List;
    my $list = Alien::Builder::Download::List->new(
      map { $_ => URI->new_abs($_, $uri) } $ftp->ls
    );
    $ftp->quit;
    return $list;
  }
  else
  {
    $ftp->quit;
    croak "no such file: $uri";
  }
}

=head2 protocols

=cut

sub protocols { 'ftp' }

1;
