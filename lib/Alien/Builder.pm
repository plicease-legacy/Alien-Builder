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

=head1 PROPERTIES

=head2 arch

=cut

sub alien_prop_arch
{
  my($self) = @_;
  $self->{arch} ||= do {
    my $arch = $self->{config}->{arch};
    $arch = $ENV{ALIEN_ARCH} unless defined $arch;
    !!$arch;
  };
}

=head2 autoconf_with_pic

=cut

sub alien_prop_autoconf_with_pic
{
  my($self) = @_;
  $self->{autoconf_with_pic} ||= do {
    my $acwp = $self->{config}->{autoconf_with_pic};
    $acwp = 1 unless defined $acwp;
    $acwp;
  };
}

=head2 bin_requires

=cut

sub alien_prop_bin_requires
{
  my($self) = @_;
  
  $self->{bin_requires} ||= do {
    my %bin_requires = %{ $self->{config}->{bin_requires} || {} };
    
    $bin_requires{'Alien::MSYS'} ||= 0 if $self->alien_prop_msys && $OS eq 'MSWin32';
    
    \%bin_requires;
  };
}

=head2 build_commands

=cut

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

=head2 build_dir

=cut

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

=head2 env

=cut

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

=head2 ffi_name

=cut

sub alien_prop_ffi_name
{
  my($self) = @_;
  $self->{ffi_name} ||= do {
    my $name = $self->{config}->{ffi_name};
    $name = $self->alien_prop_name unless defined $name;
    $name;
  };
}

=head2 helper

=cut

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

=head2 inline_auto_include

=cut

sub alien_prop_inline_auto_include
{
  my($self) = @_;
  $self->{inline_auto_include} ||= do {
    my @iai = @{ $self->{config}->{inline_auto_include} || [] };
    \@iai;
  };
}

=head2 install_commands

=cut

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

=head2 interpolator

=cut

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

=head2 isolate_dynamic

=cut

sub alien_prop_isolate_dynamic
{
  my($self) = @_;
  $self->{isolate_dynamic} ||= do {
    my $id = $self->{config}->{isolate_dynamic};
    $id = 1 unless defined $id;
    $id;
  };
}

=head2 msys

=cut

sub alien_prop_msys
{
  my($self) = @_;
  
  $self->{msys} ||= do {
    (!!$self->{config}->{msys}) || $self->_autoconf;
  };
}

=head2 name

=cut

sub alien_prop_name
{
  my($self) = @_;
  $self->{name} ||= $self->{config}->{name} || '';
}

=head2 provides_cflags

=head2 provides_libs

=cut

sub alien_prop_provides_cflags
{
  my($self) = @_;
  $self->{config}->{provides_cflags};
}

sub alien_prop_provides_libs
{
  my($self) = @_;
  $self->{config}->{provides_libs};
}

=head2 test_commands

=cut

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

=head2 version_check

=cut

sub alien_prop_version_check
{
  my($self) = @_;
  $self->{config}->{version_check} || '%{pkg_config} --modversion %n';
}

# Private properties and methods

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

# private methods

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
