package Alien::Builder::Interpolator::Default;

use strict;
use warnings;
use Alien::Builder;
use Devel::FindPerl;
use base qw( Alien::Builder::Interpolator );

# ABSTRACT: Default version of interpolator used by Alien::Builder
# VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 CONSTRUCTOR

=head2 new

=cut

sub new
{
  my($class, %args) = @_;
  
  my %vars = %{ $args{vars} || {} }; # copy;

  # handled here:
  # %x  ( perl exe )
  # %X  ( perl exe  for win )
  # handled else where:
  # %s  (alien_library_destination)
  # %c  (alien_configure)
  # %n  (alien_name)

  my $perl = Devel::FindPerl::find_perl_interpreter();
  $vars{x} = $perl;
  $perl =~ s{\\}{/}g if $Alien::Builder::OS eq 'MSWin32';
  $vars{X} = $perl;
    
  $args{vars} = \%vars;
  
  $class->SUPER::new(%args);  
}

1;
