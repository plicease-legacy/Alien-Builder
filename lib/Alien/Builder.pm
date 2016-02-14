package Alien::Builder;

use strict;
use warnings;
use Config;
use Alien::Base::PkgConfig;
use Alien::Builder::EnvLog;
use Alien::Builder::CommandList;
use Env qw( @PATH );
use File::chdir;
use Text::ParseWords qw( shellwords );
use 5.008001;

# ABSTRACT: Base classes for Alien builder modules
# VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 CONSTRUCTOR

=head2 new

=over 4

=item arch

=item autoconf_with_pic

=item bin_requires

=item build_commands

=item build_dir

=item env

=item ffi_name

=item helper

=item install_commands

=item interpolator

=item msys

=item name

=item test_commands

=back

=cut

# these are mainly for testing, and
# not intended as a public interface
our $OS        = $^O;
our $BUILD_DIR = '_alien';

sub new
{
  my($class, %args) = @_;  

  bless {
    config => {
      map { $_ => $args{$_} } 
      map { s/^alien_prop_// ? ($_) : () } 
      sort keys %Alien::Builder::
    },
  }, $class;
}

# public properties
# - properties are specified by the caller by passing in a key/value pairs
#   to the constructor.  The values should be strings, lists or hash references
#   no sub references and no objects
# - these are stored by the constuctor in the "config" hash.
# - the "config" hash is read only, nothing should EVER write to it.
# - You should be able to save the "config" has to a .json file and reconstitute
#   the builder object from that.
# - the actual value of the property is defined by a method which takes the raw
#   "config" hash values, applies any default values if they properties haven't
#   been provided, and turns the value into the thing which is actually used.
# - "thing" in this case can be either a primitive (string, hash, etc) or an
#   object.
# - only this method should read from the config hash, everything else should
#   go through the property method

sub alien_prop_arch
{
  my($self) = @_;
  !!$self->{config}->{arch};
}

sub alien_prop_autoconf_with_pic
{
  my($self) = @_;
  $self->{autoconf_with_pic} ||= do {
    my $acwp = $self->{config}->{autoconf_with_pic};
    $acwp = 1 unless defined $acwp;
    $acwp;
  };
}

sub alien_prop_bin_requires
{
  my($self) = @_;
  
  $self->{bin_requires} ||= do {
    my %bin_requires = %{ $self->{config}->{bin_requires} || {} };
    
    $bin_requires{'Alien::MSYS'} ||= 0 if $self->alien_prop_msys && $OS eq 'MSWin32';
    
    \%bin_requires;
  };
}

sub alien_prop_build_commands
{
  my($self) = @_;
  
  $self->{build_commands} ||= do {
    my @commands = @{ $self->{config}->{build_commands} || [ '%c --prefix=%s', 'make' ] };
    Alien::Builder::CommandList->new(
      \@commands, interpolator => $self->alien_prop_interpolator,
    );
  };
}

sub alien_prop_build_dir
{
  my($self) = @_;
  $self->{build_dir} ||= do {
    my $dir = $self->{config}->{build_dir} || $BUILD_DIR;
    mkdir($dir) || die "unable to create $dir $!"
      unless -d $dir;
    local $CWD = $dir;
    $CWD;
  };
}

sub alien_prop_env
{
  my($self) = @_;
  
  $self->{env} ||= do {
    my %env;
    local $ENV{PATH} = $ENV{PATH};
    my $config = $self->{env_log} = Alien::Builder::EnvLog->new;
    
    foreach my $mod (keys %{ $self->alien_prop_bin_requires }) {
      my $version = $self->alien_prop_bin_requires->{$mod};
      eval qq{ use $mod $version }; # should also work for version = 0
      die $@ if $@;

      my %path;
    
      if ($mod eq 'Alien::MSYS') {
        $path{Alien::MSYS->msys_path} = 1;
      } elsif ($mod eq 'Alien::CMake') {
        Alien::CMake->set_path;
      } elsif ($mod eq 'Alien::TinyCC') {
        $path{Alien::TinyCC->path_to_tcc} = 1;
      } elsif ($mod eq 'Alien::Autotools') {
        $path{$_} = 1 for map { Alien::Autotools->$_ } qw( autoconf_dir automake_dir libtool_dir );
      } elsif (eval { $mod->can('bin_dir') }) {
        $path{$_} = 1 for $mod->bin_dir;
      }
    
      # remove anything already in PATH
      delete $path{$_} for @PATH;
      # add anything else to start of PATH
      my @value = sort keys %path;
      unshift @PATH, @value;

      $config->prepend_path( PATH => @value );
      $env{PATH} = $ENV{PATH};
    }
    
    if($self->_autoconf && !defined $ENV{CONFIG_SITE})
    {
    
      local $CWD = $self->alien_prop_build_dir;
      
      my $ldflags = $Config{ldflags};
      $ldflags .= " -Wl,-headerpad_max_install_names"
        if $OS eq 'darwin';
      
      open my $fh, '>', 'config.site';
      print $fh "CC='$Config{cc}'\n";
      # -D define flags should be stripped because they are Perl
      # specific.
      print $fh "CFLAGS='", _filter_defines($Config{ccflags}), "'\n";
      print $fh "CPPFLAGS='", _filter_defines($Config{cppflags}), "'\n";
      print $fh "CXXFLAGS='", _filter_defines($Config{ccflags}), "'\n";
      print $fh "LDFLAGS='$ldflags'\n";
      close $fh;

      my $config_site = _catfile($CWD, 'config.site');
      $config->set( CONFIG_SITE => $config_site );
      $env{CONFIG_SITE} = $config_site;
    }
    
    foreach my $key (sort keys %{ $self->{config}->{env} || {} })
    {
      my $value = $self->alien_prop_interpolator->interpolate( $self->{config}->{env}->{$key} );
      $env{$key} = $value;
      if(defined $value)
      {
        $config->set( $key => $value );
      }
      else
      {
        $config->unset( $key );
      }
    }
    
    $config->write_log($self->alien_prop_build_dir);
    
    \%env;
  };
}

sub alien_prop_ffi_name
{
  my($self) = @_;
  $self->{ffi_name} ||= do {
    my $name = $self->{config}->{ffi_name};
    $name = $self->alien_prop_name unless defined $name;
    $name;
  };
}

sub alien_prop_helper
{
  my($self) = @_;
  $self->{helper} ||= do {
    my %helper = %{ $self->{config}->{helper} || {} };
    $helper{pkg_config} = 'Alien::Base::PkgConfig->pkg_config_command'
      unless defined $helper{pkg_config};
    \%helper;
  };
}

sub alien_prop_install_commands
{
  my($self) = @_;
  
  $self->{install_commands} ||= do {
    my @commands = @{ $self->{config}->{install_commands} || [ 'make install' ] };
    Alien::Builder::CommandList->new(
      \@commands, interpolator => $self->alien_prop_interpolator,
    );
  };
}

sub alien_prop_interpolator
{
  my($self) = @_;
  $self->{interpolator} ||= do {
    my $class = $self->{config}->{interpolator} || 'Alien::Builder::Interpolator::Default';
    unless($class->can('new'))
    {
      my $pm = $class;
      $pm =~ s{::}{/}g;
      $pm .= '.pm';
      require $pm;
    }
    $class->new(
      vars => {
        # for compat with AB::MB we do on truthiness,
        # not definedness
        n => $self->alien_prop_name,
        s => 'TODO',
        c => $self->_autoconf_configure,
      },
      helpers => $self->alien_prop_helper,
    );
  };
}

sub alien_prop_msys
{
  my($self) = @_;
  
  $self->{msys} ||= do {
    (!!$self->{config}->{msys}) || $self->_autoconf;
  };
}

sub alien_prop_name
{
  my($self) = @_;
  $self->{name} ||= $self->{config}->{name} || '';
}

sub alien_prop_test_commands
{
  my($self) = @_;
  
  $self->{test_commands} ||= do {
    my @commands = @{ $self->{config}->{test_commands} || [] };
    Alien::Builder::CommandList->new(
      \@commands, interpolator => $self->alien_prop_interpolator,
    );
  };
}

# private stuff

sub _autoconf
{
  my($self) = @_;
  $self->{autoconf} ||= do {
    !!grep /(?<!\%)\%c/, 
      map { ref $_ ? @$_ : $_ }
      map { $_->raw }
      map { $self->$_ }
      qw( alien_prop_build_commands alien_prop_install_commands alien_prop_test_commands );
  };
}

sub _autoconf_configure
{
  my($self) = @_;
  my $configure = $OS eq 'MSWin32' ? 'sh configure' : './configure';
  $configure .= ' --with-pic' if $self->alien_prop_autoconf_with_pic;
  $configure;
}

sub _env_log
{
  my($self) = @_;
  $self->alien_prop_env;
  $self->{env_log};
}

sub _catfile
{
  my $file = File::Spec->catfile(@_);
  $file =~ s{\\}{/}g if $OS eq 'MSWin32';
  $file;
}

sub _catdir
{
  my $dir = File::Spec->catdir(@_);
  $dir =~ s{\\}{/}g if $OS eq 'MSWin32';
  $dir;
}

sub _filter_defines
{
  join ' ', grep !/^-D/, shellwords($_[0]);
}

sub _do_system
{
  my($self, @cmd) = @_;
  
  # Some systems proliferate huge PERL5LIBs, try to ameliorate:
  my %seen;
  my $sep = $Config{'path_sep'};
  local $ENV{PERL5LIB} =
    ( !exists($ENV{PERL5LIB}) ? '' :
      length($ENV{PERL5LIB}) < 500
      ? $ENV{PERL5LIB}
      : join $sep, grep { ! $seen{$_}++ and -d $_ } split($sep, $ENV{PERL5LIB})
    );
  
  my $status = system(@cmd);
  if ($status and $! =~ /Argument list too long/i)
  {
    my $env_entries = '';
    foreach (sort keys %ENV) { $env_entries .= "$_=>".length($ENV{$_})."; " }
    warn "'Argument list' was 'too long', env lengths are $env_entries";
  }
  return !$status;
}

1;
