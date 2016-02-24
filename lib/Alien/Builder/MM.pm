package Alien::Builder::MM;

use strict;
use warnings;
use Storable qw( dclone );
use base qw( Alien::Builder );

# ABSTRACT: Alien::Builder subclass for ExtUtils::MakeMaker
# VERSION

sub mm_args
{
  my($self, %args) = @_;
  %args = %{ dclone(\%args) };
  
  $args{PREREQ_PM}->{'File::ShareDir'} ||= '1.00';
  
  %args;
}

1;
