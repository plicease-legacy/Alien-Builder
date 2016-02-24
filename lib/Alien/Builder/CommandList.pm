package Alien::Builder::CommandList;

use strict;
use warnings;

# ABSTRACT: Interpolate variables and helpers
# VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 CONSTRUCTOR

=head2 new

=over 4

=item interpolator

=item system

=back

=cut

sub new
{
  my($class, $command_list, %args) = @_;  
  
  bless {
    command_list => [ @{ $command_list || [] } ],
    interpolator => $args{interpolator}  || do { require Alien::Builder::Interpolator; Alien::Builder::Interpolator->new },
    system       => $args{system}        || \&CORE::system,
  }, $class;
}

=head1 METHODS

=head2 interpolate

=cut

sub interpolate
{
  my($self) = @_;
  my $intr = $self->{interpolator};
  map { ref $_ ? [map { $intr->interpolate($_) } @$_ ] : [$intr->interpolate($_)] } @{ $self->{command_list} };
}

=head2 execute

=cut

sub execute
{
  my($self) = @_;
  
  foreach my $command ($self->interpolate)
  {
    $self->{system}->(@$command);
  }
}

=head2 raw

=cut

sub raw
{
  my($self) = @_;
  map { ref $_ ? $_ : [$_] } @{ $self->{command_list} }
}

=head2 is_empty

=cut

sub is_empty
{
  my($self) = @_;
  @{ $self->{command_list} } == 0;
}

1;
