package Alien::Builder;

use strict;
use warnings;

# ABSTRACT: Base classes for Alien builder modules
# VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 CONSTRUCTOR

=head2 new

=over 4

=item bin_requires

=item env

=item msys

=back

=cut

sub new
{
  my($class, %args) = @_;  

  bless {
  }, $class;
}

1;
