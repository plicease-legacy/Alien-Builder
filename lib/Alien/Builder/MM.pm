package Alien::Builder::MM;

use strict;
use warnings;
use Storable qw( dclone );
use base qw( Alien::Builder );

# ABSTRACT: Alien::Builder subclass for ExtUtils::MakeMaker
# VERSION

=head1 METHODS

=head2 mm_args

=cut

# TODO: looks like we will also need mm_fallback method

sub mm_args
{
  my($self, %args) = @_;
  %args = %{ dclone(\%args) };
  
  $args{PREREQ_PM}->{'File::ShareDir'} ||= '1.00';
  
  my %build_requires = (%{ $self->alien_build_requires }, %{ $args{BUILD_REQUIRES} || {} });
  $args{BUILD_REQUIRES} = \%build_requires;
  
  %args;
}

=head2 mm_postamble

=cut

sub mm_postamble
{
  my($self) = @_;
  '';
}

1;
