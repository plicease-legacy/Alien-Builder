package Alien::Builder::Retrievor::Candidate;

use strict;
use warnings;
use URI;

# ABSTRACT: Retrieval candidate
# VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 CONSTRUCTOR

=head2 new

=cut

sub new
{
  my($class, $name, $location, %args) = @_;
  
  $location = URI->new($location) unless ref $location;
  
  bless {
    name     => $name,
    location => $location,
    captures => undef,
  }, $class;
}

=head1 ATTRIBUTES

=head2 name

=cut

sub name { shift->{name} }

=head2 location

=cut

sub location { shift->{location} }

=head2 captures

=cut

sub captures
{
  my($self, @new) = @_;
  if(@new)
  {
    $self->{captures} = \@new;
  }
  $self->{captures};
}

1;
