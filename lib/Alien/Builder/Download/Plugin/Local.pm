package Alien::Builder::Download::Plugin::Local;

use strict;
use warnings;
use URI;
use File::Spec;
use Carp qw( croak );

# ABSTRACT: Local file "downloader"
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
  
  croak "only works with file URL" unless $uri->scheme eq 'file';
    
  if(-d $uri->dir)
  {
    $uri->path($uri->path . '/') unless $uri->path =~ m{/$};
    my $dir = $uri->dir;
    my $dh;
    opendir $dh, $dir;
    my @list = grep !/^\./, readdir $dh;
    closedir $dh;
    require Alien::Builder::Download::List;
    return Alien::Builder::Download::List->new(
      map { $_ => URI->new_abs($_, $uri) } @list
    );
  }
  elsif(-f $uri->file)
  {
    my (undef,undef,$filename) = File::Spec->splitpath( $uri->file );
    require Alien::Builder::Download::File;
    return Alien::Builder::Download::File->new(
      localfile => $uri->file,
      filename  => $filename,
    );
  }
  else
  {
    croak "no such file or directory: $uri";
  }
}

=head2 protocols

=cut

sub protocols { 'file' }

1;
