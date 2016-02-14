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

=item env

=back

=cut

sub new
{
  my($class, $command_list, %args) = @_;  
  
  unless($args{interpolator})
  {
    require Alien::Builder::Interpolator;
    $args{interpolator} = Alien::Builder::Interpolator->new;
  }
  
  bless {
    command_list => [ @{ $command_list || [] } ],
    interpolator => $args{interpolator}  || \&CORE::system,
    system       => $args{system}        || [],
    env          => $args{env}           || {},
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
  
  local %ENV = %ENV;

  while(my($k,$v) = each %{ $self->{env} })
  {
    if(defined $v)
    {
      $ENV{$k} = $v;
    }
    else
    {
      delete $ENV{$k};
    }
  }
  
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

1;
