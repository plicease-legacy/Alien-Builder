package Alien::Builder::Download::List;

use strict;
use warnings;

# ABSTRACT: Directory listing for Alien::Builder
# VERSION

=head1 CONSTRUCTOR

=head2 new

=over 4

=item 

=back

=cut

sub new
{
  my($class, %list) = @_;
  bless \%list, $class;
}

=head1 METHODS

=head2 list

=cut

sub list
{
  my($self) = @_;
  sort keys %$self;
}

=head2 uri_for

=cut

sub uri_for
{
  my($self, $key) = @_;
  $self->{$key};
}

=head2 is_file

=cut

sub is_file { 0 }

1;
