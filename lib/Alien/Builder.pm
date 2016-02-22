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
use Capture::Tiny qw( tee capture );
use Scalar::Util qw( weaken );
use 5.008001;

# ABSTRACT: Base classes for Alien builder modules
# VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 CONSTRUCTOR

=head2 new

 my $builder = Alien::Builder->new(%properties);

Create a new instance of L<Alien::Builder>.

=cut

# these are mainly for testing, and
# not intended as a public interface
our $OS        = $^O;
our $BUILD_DIR = '_alien';
our $DO_SYSTEM;
our $VERBOSE   = $ENV{ALIEN_VERBOSE};

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

Properties can be specified by passing them into L</new> as arguments.  
They can be accessed after the L<Alien::Builder> object is created using 
the C<alien_prop_> prefix.  For example:

 my $builder = Alien::Builder->new( arch => 1 );
 $builder->alien_prop_arch; # is 1

=head2 arch

Install module into an architecture specific directory. This is off by 
default, unless C<$ENV{ALIEN_ARCH}> is true. Most Alien distributions 
will be installing binary code. If you are an integrator where the 
C<@INC> path is shared by multiple Perls in a non-homogeneous 
environment you can set C<$ENV{ALIEN_ARCH}> to 1 and Alien modules will 
be installed in architecture specific directories.

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

Add C<--with-pic> option to autoconf style configure script when called. 
This is the default, and normally a good practice. Normally autoconf 
will ignore this and any other options that it does not recognize, but 
some non-autoconf C<configure> scripts may complain.

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

Hash reference of modules (keys) and versions (values) that specifies 
L<Alien> modules that provide binary tools that are required to build.  
Any L<Alien::Base> that includes binaries should work.  Also supported 
are L<Alien::MSYS>, L<Alien::CMake>, L<Alien::TinyCC> and 
L<Alien::Autotools>.  These become build time requirements for your 
module if L<Alien::Builder> determines that a source code build is 
required.

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

An array reference of commands used to build the library in the 
directory specified in L</build_dir>.  Each command is first passed 
through the L<command interpolation engine|/COMMAND INTERPOLATION>, so 
any variable or helper provided may be used.  The default is tailored to 
the GNU toolchain (that is autoconf and C<make>); it is
C<[ '%c --prefix=%s', 'make' ]>.  Each command may be either a string or 
an array reference.  If the array reference form is used then the 
multiple argument form of system is used.

=cut

sub alien_prop_build_commands
{
  my($self) = @_;
  weaken $self;
  $self->{build_commands} ||= do {
    my @commands = @{ $self->{config}->{build_commands} || [ '%c --prefix=%s', 'make' ] };
    Alien::Builder::CommandList->new(
      \@commands, 
      interpolator => $self->alien_prop_interpolator,
      system       => sub { $self->alien_do_system(@_, { interpolate => 0 }) },
    );
  };
}

=head2 build_dir

The name of the folder which will house the library where it is 
downloaded and built.  The default name is C<_alien>.

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

Environment overrides.  Allows you to set environment variables as a 
hash reference that will override environment variables.  You can use 
the same interpolated escape sequences and helpers that commands use.  
Set to C<undef> to remove the environment variable.

 Alien::Builder->new(
   env => {
     PERL => '%X',     # sets the environment variable PERL to the location
                       # of the Perl interpreter.
     PERCENT => '%%',  # evaluates to '%'
     REMOVE  => undef, # remove the environment variable if it is defined
   },
 );

Please keep in mind that frequently users have a good reason to have set 
environment variables, and you should not override them without a good 
reason. An example of a good justification would be if a project has a 
Makefile that interacts badly with common environment variables. This 
can sometimes be a problem since Makefile variables can be overridden 
with environment variables.

A useful pattern is to use a helper to only override an environment 
variable if it is not already set.

 Alien::Builder->new(
   helper => {
     foo => '$ENV{FOO}||"my preferred value if not already set"',
   },
   env => {
     FOO => '%{foo}',
   },
 );

A common pitfall with environment variables is that setting one to the 
empty string ('') is not portable. On Unix it works fine as you would 
expect, but in Windows it actually unsets the environment variable, 
which may not be what you intend.

 Alien::Builder->new(
   env => {
     FOO => '', # is allowed, but may not do what you intend on some platforms!
   },
 );
 
 $ENV{FOO} = ''; # same issue.

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

=head2 extractor

The extractor class.  This is 
L<Alien::Builder::Extractor::Plugin::ArchiveTar> by default.

=cut

sub alien_prop_extractor
{
  my($self) = @_;
  $self->{extractor} ||= do {
    $self->_class(
      $self->{config}->{extractor},
      'Alien::Builder::Extractor::Plugin',
      'ArchiveTar',
      'extract',
    );
  };
}

=head2 ffi_name

The name of the shared library for use with FFI.  Provided for 
situations where the shared library name cannot be determined from the 
C<pkg-config> name specified as L</name>.  For example, C<libxml2> has a 
C<pkg-config> name of C<libxml-2.0>, but a shared library name of 
C<xml2>.  By default L</name> is used with any C<lib> prefix removed. 
For example if you specify a L</name> of C<libarchive>, L</ffi_name> 
will be C<archive>.

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

Provide helpers to generate commands or arguments at build or install 
time. This property is a hash reference. The keys are the helper names 
and the values are strings containing Perl code that will be evaluated 
and interpolated into the command before execution. Because helpers are 
only needed when building a package from the source code, any dependency 
may be specified as an L</bin_requires>. For example:

 Alien::Builder->new(
   bin_requires => {
     'Alien::foo' => 0,
   },
   helper => {
     'foocommand'  => 'Alien::foo->some_command',
     'fooargument' => 'Alien::foo->some_argument',
   },
   build_commands => [
     '%{foocommand} %{fooargument}',
   ],
 );

One helper that you get for free is C<%{pkg_config}>, which will be the 
C<pkg-config> implementation chosen by L<Alien::Builder>.  This will 
either be the "real" C<pkg-config> provided by the operating system 
(preferred), or L<PkgConfig>, the pure perl implementation found on 
CPAN.

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

Array reference containing the list of header files to be used 
automatically by L<Inline::C> and L<Inline::CPP>.

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

An array reference of commands used to install the library in the 
directory specified in L</build_dir>.  Each command is first passed 
through the L<command interpolation engine|/COMMAND INTERPOLATION>, so 
any variable or helper provided may be used.  The default is tailored to 
the GNU toolchain (that is autoconf and C<make>); it is
C<[ 'make install' ]>.  Each command may be either a string or an array 
reference.  If the array reference form is used then the multiple 
argument form of system is used.

=cut

sub alien_prop_install_commands
{
  my($self) = @_;
  weaken $self;
  $self->{install_commands} ||= do {
    my @commands = @{ $self->{config}->{install_commands} || [ 'make install' ] };
    Alien::Builder::CommandList->new(
      \@commands,
      interpolator => $self->alien_prop_interpolator,
      system       => sub { $self->alien_do_system(@_, { interpolate => 0 }) },
    );
  };
}

=head2 interpolator

The interpolator class.  This is 
L<Alien::Builder::Interpolator::Default> by default.

=cut

sub alien_prop_interpolator
{
  my($self) = @_;
  $self->{interpolator} ||= do {
    my($class) = $self->_class(
      $self->{config}->{interpolator},
      'Alien::Builder::Interpolator',
      'Default'
    );
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

If set to true (the default), then dynamic libraries will be moved from 
the lib directory to a separate dynamic directory. This makes them 
available for FFI modules (such as L<FFI::Platypus>, or L<FFI::Raw>), 
while preferring static libraries when creating C<XS> extensions.

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

On windows wrap build and install commands in an C<MSYS> environment using 
L<Alien::MSYS>. This option will automatically add L<Alien::MSYS> as a build 
requirement when building on Windows.

=cut

sub alien_prop_msys
{
  my($self) = @_;
  
  $self->{msys} ||= do {
    (!!$self->{config}->{msys}) || $self->_autoconf;
  };
}

=head2 name

The name of the primary library which will be provided.  This should be 
in the form to be passed to C<pkg-config>.

=cut

sub alien_prop_name
{
  my($self) = @_;
  $self->{name} ||= $self->{config}->{name} || '';
}

=head2 provides_cflags

=head2 provides_libs

These parameters, if specified, augment the information found by 
C<pkg-config>. If no package config data is found, these are used to 
generate the necessary information. In that case, if these are not 
specified, they are attempted to be created from found shared-object 
files and header files. They both are empty by default.

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

An array reference of commands used to test the library in the directory 
specified in L</build_dir>.  Each command is first passed through the 
L<command interpolation engine|/COMMAND INTERPOLATION>, so any variable 
or helper provided may be used.  The default is not to run any tests; it 
is C<[]>. Each command may be either a string or an array reference.  If 
the array reference form is used then the multiple argument form of 
system is used.

=cut

sub alien_prop_test_commands
{
  my($self) = @_;
  weaken $self;
  $self->{test_commands} ||= do {
    my @commands = @{ $self->{config}->{test_commands} || [] };
    Alien::Builder::CommandList->new(
      \@commands,
      interpolator => $self->alien_prop_interpolator,
      system       => sub { $self->alien_do_system(@_, { interpolate => 0 }) },
    );
  };
}

=head2 version_check

A command to run to check the version of the library installed on the 
system.  The default is C<pkg-config --modversion %n>.

=cut

sub alien_prop_version_check
{
  my($self) = @_;
  $self->{config}->{version_check} || '%{pkg_config} --modversion %n';
}

=head1 METHODS

=head2 alien_check_installed_version

 my $version = $builder->alien_check_installed_version;

This function determines if the library is already installed as part of 
the operating system, and returns the version as a string. If it can't 
be detected then it should return empty list.

The default implementation relies on C<pkg-config>, but you will 
probably want to override this with your own implementation if the 
package you are building does not use C<pkg-config>.

=cut

sub alien_check_installed_version
{
  my($self) = @_;
  my $command = $self->alien_prop_version_check;
  my %result = $self->alien_do_system($command, { verbose => 0 });
  my $version = ($result{success} && $result{stdout}) || 0;
  return $version;
}

=head2 alien_check_built_version

 my $version = $builder->alien_check_built_version;

This function determines the version of the library after it has been 
built from source. This function only gets called if the operating 
system version can not be found and the package is successfully built.

The default implementation relies on C<pkg-config>, and other heuristics, 
but you will probably want to override this with your own implementation 
if the package you are building does not use C<pkg-config>.

When this method is called, the current working directory will be the 
build root.

If you see an error message like this:

 Library looks like it installed, but no version was determined

After the package is built from source code then you probably need to 
provide an implementation for this method.

=cut

sub alien_check_built_version
{
  my($self) = @_;
  return;
}

=head2 alien_do_system

 my %result = $builder->alien_do_system($cmd);
 my %result = $builder->alien_do_system(@cmd);

Executes the given command using either the single argument or multiple 
argument form.  Before executing the command, it will be interpolated 
using the L<command interpolation engine|/COMMAND INTERPOLATION>.

Returns a set of key value pairs including C<stdout>, C<stderr>, 
C<success> and C<command>.

=cut

sub alien_do_system
{
  my($self, @args) = @_;
  my $opts = ref $args[-1] ? pop : { verbose => 1, interpolate => 1 };
  
  local %ENV = %ENV;
  foreach my $key (sort keys %{ $self->alien_prop_env })
  {
    my $value = $self->alien_prop_env->{$key};
    if(defined $value)
    {
      $ENV{$key} = $value;
    }
    else
    {
      delete $ENV{$key};
    }
  }
  
  my $verbose = $VERBOSE || $opts->{verbose};
  
  # prevent build process from cwd-ing from underneath us
  local $CWD;
  my $initial_cwd = $CWD;

  @args = map { $self->alien_prop_interpolator->interpolate($_) } @args
    unless $opts->{interplate};
  print "+ @args\n";
  
  my($out, $err, $success) =
    $verbose
    ? tee     { $DO_SYSTEM->(@args) }
    : capture { $DO_SYSTEM->(@args) }
  ;
  
  my %return = (
    stdout => $out,
    stderr => $err,
    success => $success,
    command => join(' ', @args),
  );
  
  # return wd
  $CWD = $initial_cwd;
  
  return wantarray ? %return : $return{success};
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

sub _class
{
  my(undef, $name, $default_prefix, $default_name, $method) = @_;
  $name = $default_name unless defined $name;
  $method ||= 'new';
  my $class = ($name||'') =~ /::/ ? $name : defined $name ? join('::', $default_prefix, $name) : $default_prefix;
  unless($class->can($method))
  {
    my $pm = $class;
    $pm =~ s{::}{/}g;
    $pm .= '.pm';
    require $pm;
  }
  $class;
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


$DO_SYSTEM = sub
{
  my @cmd = @_;
  
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
};

1;

=head1 ENVIRONMENT

=head2 ALIEN_ARCH

Setting this changes the default for L</arch> above. If the module 
specifies its own L</arch> then it will override this setting. Typically 
installing into an architecture specific directory is what you want to 
do, since most L<Alien::Base> based distributions provide architecture 
specific binary code, so you should consider carefully before installing 
modules with this environment variable set to C<0>. This may be useful 
for integrators creating a single non-architecture specific C<RPM>, 
C<.dep> or similar package. In this case the integrator should ensure 
that the Alien package be installed with a system install_type and use 
the system package.

=head2 ALIEN_INSTALL_TYPE

Setting to C<share> will ignore a system-wide installation and build a 
local version of the library.  Setting to C<system> will only use a 
system-wide installation and die if it cannot be found.

=head1 COMMAND INTERPOLATION

Before L<Alien::Builder> executes system commands, or applies 
environment overrides, it replaces a few special escape sequences with 
useful data.  This is needed especially for referencing the full path to 
the appropriate install location before the path is known.  The 
available sequences are:

=over 4

=item C<%{helper}>

Evaluate the given helper, as provided by either the L</helper> or 
L</bin_requires> property.  See L<Alien::Base#alien_helper>.

=item C<%c>

Platform independent incantation for running autoconf C<configure> 
script.  On Unix systems this is C<./configure>, on Windows this is
C<sh configure>.  On windows L<Alien::MSYS> is injected as a dependency 
and all commands are executed in a C<MSYS> environment.

=item C<%n>

Shortcut for the name stored in L</name>.  The default is:
C<pkg-config --modversion %n>

=item C<%s>

The full path to the final installed location of the share directory. 
This is where the library should install itself; for autoconf style 
installs, this will look like C<--prefix=%s>.

=item C<%v>

Captured version of the original archive.

=item C<%x>

The current Perl interpreter (similar to C<$^X>).

=item C<%X>

The current Perl interpreter using the Unix style path separator C</> 
instead of native Windows C<\>.

=item C<%%>

A literal C<%>.

=back

=head1 SEE ALSO

=over 4

=item L<Alien::Base>

Runtime access to configuration determined by L<Alien::Builder> and 
build time.

=item L<Alien>

The original L<Alien> manifesto.

=back

=cut
