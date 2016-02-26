package Alien::Builder::PkgConfig;

use strict;
use warnings;
use base qw( Alien::Base::PkgConfig );

# ABSTRACT: PkgConfig class for Alien::Builder
# VERSION

sub TO_JSON
{
  my($self) = @_;
  my %hash = %$self;
  $hash{'__CLASS__'} = 'Alien::Builder::PkgConfig';
  \%hash;
}

1;
