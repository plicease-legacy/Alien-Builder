package Alien::Builder::Retrievor;

use strict;
use warnings;
use Alien::Builder;
use Alien::Builder::Download;

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
    selections => [@selections],
  }, $class;
}

=head1 METHODS

=head2 retrieve

=cut

sub retrieve
{
  my($self) = @_;
  
  my $download = Alien::Builder::Download->get($self->{first});
  $self->_recurse($download, @{ $self->{selections} });
}

=head1 SELECTIONS

=head2 candidate_class

=head2 pattern

=cut

sub _recurse
{
  my($self, $download, @selections) = @_;
  
  if($download->is_file)
  {
    die "Got file when there are selections remaining" if @selections > 0;
    return $download;
  }
  else
  {
    $DB::single = 1;
    my $selection = shift @selections;
    
    my $can_class = Alien::Builder->_class(
      $selection->{candidate_class},
      'Alien::Builder::Retrievor::Candidate',
    );
    
    my @can = map { $can_class->new($_ => $download->uri_for($_) ) } $download->list;
    
    # TODO: list of patterns,
    # TODO: negate pattern
    if($selection->{pattern})
    {
      my $pattern = $selection->{pattern};
      $pattern = qr{$pattern} unless ref $pattern eq 'Regexp';
      @can = grep { $_->captures($_->name =~ $pattern) } @can;
    }
    
    die "no canidates remaining" unless @can > 0;
    
    $self->{candidates} = \@can;
    
    return $self->_recurse(Alien::Builder::Download->get($can[-1]->location));
  }
}

sub _candidates
{
  my($self) = @_;
  
  @{ $self->{candidates} };
}

1;
