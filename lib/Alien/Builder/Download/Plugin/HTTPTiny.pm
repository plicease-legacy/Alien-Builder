package Alien::Builder::Download::Plugin::HTTPTiny;

use strict;
use warnings;
use HTTP::Tiny;
use URI;
use File::Spec;
use File::Spec::Unix;
use File::Temp qw( tempdir );
use Carp qw( croak );

# ABSTRACT: HTTP downloader using HTTP::Tiny
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
  
  croak "only works with http,https URLs" unless $uri->scheme =~ /^https?$/;
  
  my(undef, undef, $filename) = File::Spec::Unix->splitpath($uri->path);
  
  my $localfile = File::Spec->catfile(
    tempdir( CLEANUP => 1 ),
    'data',
  );
  
  my $res = HTTP::Tiny->new->mirror($uri, $localfile);
  
  die "failed downloading $uri @{[ $res->{status} || 'xxx' ]} @{[ $res->{reason} || '' ]}"
    unless $res->{success};
  
  my $disposition = $res->{headers}->{'content-disposition'};
  if(defined($disposition) && ($disposition =~ /filename="([^"]+)"/ || $disposition =~ /filename=([^\s]+)/))
  {
    $filename = $1;
  }
  
  if($res->{headers}->{'content-type'} =~ /^text\/html/)
  {
    require HTML::Parser;
    
    my %list;
    
    HTML::Parser->new(
      api_version => 3,
      start_h => [ sub {
        my($tagname, $attr) = @_;
        
        # skip all tags that aren't an a with
        # the href pointing to an aspell tarball
        return unless $tagname eq 'a' && $attr->{href};

        # convert href into an absolute URL
        my $url = URI->new_abs( $attr->{href}, $res->{url} );
        my(undef,undef,$filename) = File::Spec::Unix->splitpath($url->path);
        
        $list{$filename} = $url;
        
      }, "tagname, attr" ]
    )->parse(do {
      open my $fh, '<', $localfile;
      local $/;
      <$fh>;
    });
    
    require Alien::Builder::Download::List;
    return Alien::Builder::Download::List->new(%list);
  }
  else
  {
    require Alien::Builder::Download::File;
    return Alien::Builder::Download::File->new(
      localfile => $localfile,
      filename  => $filename,
      move      => 1,
    );
  }
}

=head2 protocols

=cut

sub protocols { qw( http https ) }

1;
