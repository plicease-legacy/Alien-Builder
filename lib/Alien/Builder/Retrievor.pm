package Alien::Builder::Retrievor;

use strict;
use warnings;

# ABSTRACT: Remote resource retrievor for Alien::Builder
# VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 CONSTRUCTOR

=head2 new

=cut

sub new
{
  my($class, $first, @selections) = @_;
  bless {
    first      => $first,
    selections => [map { %$_ } @selections],
  }, $class;
}

=head1 METHODS

=head2 retrieve

=cut

sub retrieve
{
  my($self) = @_;
}

1;
