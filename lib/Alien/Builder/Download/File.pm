package Alien::Builder::Download::File;

use strict;
use warnings;
use Carp qw( croak );
use File::Spec;

# ABSTRACT: File downloaded for Alien::Builder
# VERSION

=head1 CONSTRUCTOR

=head2 new

=over 4

=item localfile

=item filename

=item content

=item move

=back

=cut

sub new
{
  my($class, %args) = @_;
  
  croak "filename is required" unless defined $args{filename};
  croak "content or localfile is required" unless defined $args{localfile} || defined $args{content};
  
  bless {
    map { $_ => $args{$_} } qw( localfile filename content move )
  }, $class;
}

=head1 METHODS

=head2 copy_to

=cut

sub copy_to
{
  my($self, $location) = @_;
  
  my $filename = File::Spec->catfile($location, $self->{filename});
  
  if($self->{localfile})
  {
    require File::Copy;
    if($self->{move})
    {
      File::Copy::move($self->{localfile}, $filename)
        || die "unable to copy @{[ $self->{localfile} ]} to $filename $!";
    }
    else
    {
      File::Copy::copy($self->{localfile}, $filename)
        || die "unable to copy @{[ $self->{localfile} ]} to $filename $!";
    }
  }
  else
  {
    my $fh;
    open($fh, '>', $filename) || die "unable to write to $filename $!";
    binmode $fh;
    print $fh $self->{content};
    close $fh;
  }
  
  $filename;
}

# intended for testing only
# not a public interface
sub _localfile { shift->{localfile} }
sub _content   { shift->{content}   }
sub _filename  { shift->{filename}  }

1;
