package Alien::Builder::Download;

use strict;
use warnings;
use URI;
use File::Spec;

# ABSTRACT: Alien::Builder interface for downloading
# VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=head2 get

=cut

sub get
{
  my(undef, $uri, $class) = @_;
  
  my @classes = __PACKAGE__->_choose($uri, $class);
  
  my $error;
  
  foreach my $class (@classes)
  {
    my $download = eval { $class->get($uri) };
    if($error = $@)
    {
      next;
    }
    else
    {
      return $download;
    }
  }
  
  $error = "No download plugin for $uri" unless defined $error;
  die $error;
}

our @defaults = qw( LWP HTTPTiny Local NetFTP GitWrapper );
unshift @defaults, split /,/, $ENV{ALIEN_BUILDER_DOWNLOAD_PLUGINS}
  if defined $ENV{ALIEN_BUILDER_DOWNLOAD_PLUGINS};

sub _choose
{
  my(undef, $uri, $class) = @_;
  
  $uri = URI->new($uri);
  
  local @defaults = @defaults;
  unshift @defaults, $class if defined $class;
  
  my @classes;
  my %fallbacks;
  
  foreach my $inc (@INC)
  {
    File::Spec->catdir($inc, qw( Alien Builder Download Plugin ));
    next unless -d $inc;
    my $dh;
    opendir $dh, $inc;
    $fallbacks{$_} = 1 for map { s/\.pm$//; $_ } grep /\.pm$/, grep !/\./, grep { -f $_ } grep { -r $_ } readdir $dh;
    closedir $dh;
  }
  
  delete $fallbacks{$_} for @defaults;
  
  foreach my $class (map { $_ =~ /::/ ? $_ : "Alien::Builder::Download::Plugin::$_" } (@defaults, sort keys %fallbacks))
  {
    unless($class->can('protocols'))
    {
      my $pm = $class;
      $pm =~ s{::}{/}g;
      $pm .= '.pm';
      eval { require $pm };
      next if $@;
    }
    next unless eval { grep { $uri->scheme eq $_ } $class->protocols };
    push @classes, $class;
  }
  
  @classes;
}

1;
