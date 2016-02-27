package Alien::Builder::MM;

use strict;
use warnings;
use Carp qw( croak );
use Storable qw( dclone );
use File::Spec;
use File::Basename ();
use File::Path ();
use base qw( Alien::Builder );

# ABSTRACT: Alien::Builder subclass for ExtUtils::MakeMaker
# VERSION

=head1 CONSTRUCTOR

=head2 new

=cut

sub new
{
  my($self, %args) = @_;
  unless($args{prefix})
  {
    croak "I need to know the dist name of your distribution" unless $args{dist_name};
    $args{prefix} = File::Spec->rel2abs( File::Spec->catdir( qw( blib lib auto share dist ), delete $args{dist_name} ) );
  }
  $self->SUPER::new(%args);
}

=head1 METHODS

=head2 mm_args

=cut

sub mm_args
{
  my($self, %args) = @_;
  %args = %{ dclone(\%args) };
  
  $args{PREREQ_PM}->{'File::ShareDir'} ||= '1.00';
  
  my %build_requires = (%{ $self->alien_build_requires || {} }, %{ $args{BUILD_REQUIRES} || {} });
  $args{BUILD_REQUIRES} = \%build_requires;
  
  %args;
}

=head2 mm_postamble

=cut

sub mm_postamble
{
  my($self) = @_;
  
  # I DO so love to muck around with Makefiles.
  # so thankful to be able to do that.
  # THANKS OBAMA!
  
  my $postamble = '';
  my $last_target;
  
  my $build_dir = File::Spec->abs2rel($self->build_dir);
  my $state_dir = File::Spec->catfile( $build_dir, '_mm' );
  
  foreach my $action (qw( download extract build test install ))
  {
    my $flag = File::Spec->catfile( $state_dir => $action);
    my $dep  = $last_target ? "alien_$last_target" : $state_dir;
    $postamble .= "\nalien_$action: $dep $flag\n";
  
    $postamble .= "$flag:\n" .
    "\t\$(FULLPERL) -Iinc -MAlien::Builder::MM=cmds -e $action\n" .
    "\t\$(TOUCH) $flag\n";
    
    $last_target = $action;
  }
  
  $postamble .= "\n\nrealclean purge :: alien_clean\n";
  $postamble .= "alien_clean:\n\t\$(RM_RF) $build_dir\n\t\$(RM_F) alien_builder.json\n";
  $postamble .= "pure_all :: alien_install\n";
  $postamble .= "$state_dir :\n\t\$(MKPATH) $state_dir\n";
  
  $postamble;
}

=head2 action_install

=cut

sub action_install
{
  my($self) = @_;
  $self->SUPER::action_install;
  
  my $dist_name = $self->_mm_dist_name;
  
  if($self->arch)
  {
    my @name = split /-/, $dist_name;
    my $dir = File::Spec->catdir  (qw( blib arch auto ), @name);
    my $file = File::Spec->catfile($dir, $name[-1].'.txt');
    
    File::Path::mkpath($dir, { verbose => 0 }) unless -d $dir;
    open my $fh, '>', $file;
    print $fh "Alien based distribution with architecture specific file in share\n";
    close $fh;
    
  }

  my $dir  = File::Spec->catdir(qw( blib lib ), split /-/, "$dist_name-Install");
  my $file = File::Spec->catfile($dir, 'Files.pm');
  my $package = "$dist_name";
  $package =~ s/-/::/g;
  File::Path::mkpath($dir, { verbose => 0 }) unless -d $dir;
  open my $fh, '>', $file;
  print $fh <<EOF;
package $package\::Install::Files;
require $package;
sub Inline { shift; $package->Inline(\@_) }
1;
EOF
  print $fh "\n=begin Pod::Coverage\n\n  Inline\n\n=end Pod::Coverage\n\n=cut\n";
  close $fh;
  
  $self;
}

sub _mm_dist_name
{
  my($self) = @_;
  my @dirs = File::Spec->splitdir((File::Spec->splitpath($self->prefix, 1))[1]);
  my $dist_name = $dirs[-1];
}

sub import
{
  my(undef, @args) = @_;
  foreach my $arg (@args)
  {
    if($arg eq 'cmds')
    {
      package main;
      
        foreach my $action (qw( download extract build test install ))
        {
          my $method = "action_$action";
          my $sub = sub {
            my $ab = Alien::Builder->restore;
            $ab->$method;
            $ab->save;
          };
          no strict 'refs';
          *{$action} = $sub;
        };
    }
      
  }
}

1;
