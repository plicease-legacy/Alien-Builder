package Alien::Builder;

use strict;
use warnings;
use Config;
use Alien::Builder::PkgConfig;
use Alien::Builder::EnvLog;
use Alien::Builder::CommandList;
use File::Find ();
use Env qw( @PATH );
use File::chdir;
use Text::ParseWords qw( shellwords );
use Capture::Tiny qw( tee capture );
use Scalar::Util qw( weaken );
use JSON::PP;
use 5.008001;

# ABSTRACT: Base classes for Alien builder modules
# VERSION

=head1 SYNOPSIS

Create a simple instance:

 use Alien::Builder;

 my $ab = Alien::Builder->new(
   name => 'foo',
   retreiver => [
     'http://example.com/dist/' => {
       pattern => qr{^libfoo-(([0-9]\.)*[0-9]+)\.tar\.gz$},
     },
   ],
   # these are the default command lists
   build_commands => [ '%c --prefix=%s', 'make' ],
   install_commands => [ 'make install' ],
 );

Install standalone:

 use Alien::Builder;
 
 my $ab = Alien::Builder->new(
   # same as above
 );
 
 $ab->action_download
    ->action_extract
    ->action_build
    ->action_test
    ->action_install;

Deploy with L<ExtUtils::MakeMaker> (see L<Alien::Builder::MM> for more details):

 use ExtUtils::MakeMaker;
 use Alien::Builder::MM;
 
 my $ab = Alien::Builder::MM->new(
   # same as above
 );
 
 WriteMakefile(
   $ab->mm_args(
     NAME => 'Alien::Foo',
     VERSION_FROM => 'Alien::Foo'
   ),
 );
 
 sub MY::postamble {
   $ab->mm_postamble;
 }

Deploy with L<Module::Build>, see L<Alien::Base::ModuleBuild>.

=head1 DESCRIPTION

B<WARNING>: this interface is B<EXPERIMENTAL>.  If you need something stable right
now, use L<Alien::Base::ModuleBuild>.

The purpose of this class is to provide a generic builder/installer that can be used
by L<ExtUtils::MakeMaker> and L<Module::Build> derivatives for creating L<Alien>
distributions.  Basically this class provides the generic machinery used during the
configure and build stages, and L<Alien::Base> can be used at runtime once the L<Alien>
module is already installed.  It could also be used independently of an installer to
install a library.

The design goals of this library are to make the "easy" things easy, and hard things
possible.  For this discussion, "easy" means build and install libraries that use
the standard GNU style autotools, or generic Makefiles.  Harder things may require
writing Perl code, and you can accomplish this by subclassing L<Alien::Builder>.

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

  # TODO
  # this doesn't allow for defining properties in a subclass
  # which we will eventually want to support.
  foreach my $prop (grep s/^build_prop_//, keys %Alien::Builder::)
  {
    next if __PACKAGE__->can($prop);
    my $accessor_method = sub {
      my($self) = @_;
      $self->{prop_cache}->{$prop} ||= do {
        my $builder_method = "build_prop_$prop";
        $self->$builder_method;
      };
    };
    no strict 'refs';
    *{$prop} = $accessor_method;
  }

  my $self = bless {
    init => {
      map { $_ => $args{$_} } 
      map { s/^build_prop_// ? ($_) : () } 
      sort keys %Alien::Builder::
    },
    config => {},
  }, $class;

  $self->{config}->{inline_auto_include} = $self->inline_auto_include;
  $self->{config}->{name}                = $self->name;
  $self->{config}->{ffi_name}            = $self->ffi_name;
  $self->{config}->{msys}                = $self->msys;
  $self->{config}->{original_prefix}     = $self->prefix;

  if($self->install_type eq 'share')
  {
    if($self->msys)
    {
      $self->{build_requires}->{'Alien::MSYS'} = 0;
    }
    
    if($self->dest_dir)
    {
      # TODO: which version is best?
      $self->{build_requires}->{'File::Copy::Recursive'} = 0;
    }
  
    foreach my $tool (keys %{ $self->bin_requires })
    {
      my $version = $self->bin_requires->{$tool};
      if($tool eq 'Alien::CMake' && $version < 0.07)
      {
        $version = '0,07';
      }
      $self->{build_requires}->{$tool} = $version;
    }
  }

  if(defined $self->provides_cflags || defined defined $self->provides_libs)
  {
    my %provides;
    $provides{Cflags} = $self->provides_cflags if defined $self->provides_cflags;
    $provides{Libs}   = $self->provides_libs   if defined $self->provides_libs;
    $self->{config}->{system_provides} = \%provides;
  }

  $self;
}

# public properties
# - properties are specifie by the caller by passing in key/value pairs
#   to the construtor.  The values should be strings, lists of hash references
#   no sub references and no objects!
# - These are stored by the constructor into the "init" hash.
# - The "init" hash is read only, actual properties might manifest at run time
#   as objects and/or default values.  These derivitive forms will be stored
#   in "prop_cache" hash.
# - Only new should write into the "init" hash.
# - Only the build_prop_ methods should write into the "prop_cache" hash.
# - Conversion from a "init" property to a "prop_cache" property should be
#   deterministic, so that a given builder object can be completely and
#   deterministically recreated from just the arguments passed into new.
# - This way the "init" hash can be saved to JSON, and we can recreate the
#   builder object on a subsequent call.
# - properties are definied by creating a method with a "build_prop_" prefix.
# - the associated accessor method will automatically be generated.
# - ONLY the builder method for a particular property should be reading the
#   raw "init" hash value.  Anything else should call the accessor method.

=head1 PROPERTIES

At the minimum you will want to define a L</retriever> specification.
Unless your tool or library uses GNU autotools style interface (that is
it is installed with something like "./configure && make && make install")
you will need to also provide build and install commands with the
L</build_commands> and L</install_commands> properties.  Depending on
the complexity of your tool or library you may need to specify additional
properties.

Properties are read-only and can only be specified when passing them into
L</new> as arguments.  They can be accessed after the L<Alien::Builder>
object is created using accessor methods of the same name.

 my $builder = Alien::Builder->new( arch => 1 );
 $builder->arch; # is 1

=head2 arch

Install module into an architecture specific directory. This is off by 
default, unless C<$ENV{ALIEN_ARCH}> is true. Most Alien distributions 
will be installing binary code. If you are an integrator where the 
C<@INC> path is shared by multiple Perls in a non-homogeneous 
environment you can set C<$ENV{ALIEN_ARCH}> to 1 and Alien modules will 
be installed in architecture specific directories.

=cut

sub build_prop_arch
{
  my($self) = @_;
  my $arch = $self->{init}->{arch};
  $arch = $ENV{ALIEN_ARCH} unless defined $arch;
  !!$arch;
}

=head2 autoconf_with_pic

Add C<--with-pic> option to autoconf style configure script when called. 
This is the default, and normally a good practice. Normally autoconf 
will ignore this and any other options that it does not recognize, but 
some non-autoconf C<configure> scripts may complain.

=cut

sub build_prop_autoconf_with_pic
{
  my($self) = @_;
  my $acwp = $self->{init}->{autoconf_with_pic};
  $acwp = 1 unless defined $acwp;
  $acwp;
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

sub build_prop_bin_requires
{
  my($self) = @_;
  
  my %bin_requires = %{ $self->{init}->{bin_requires} || {} };
  
  $bin_requires{'Alien::MSYS'} ||= 0 if $self->msys && $OS eq 'MSWin32';
  
  \%bin_requires;
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

sub build_prop_build_commands
{
  my($self) = @_;
  weaken $self;
  my @commands = @{ $self->{init}->{build_commands} || [ '%c --prefix=%s', 'make' ] };
  Alien::Builder::CommandList->new(
    \@commands, 
    interpolator => $self->interpolator,
    system       => sub { $self->_alien_do_system_for_command_list(@_) },
  );
}

=head2 build_dir

The name of the folder which will house the library where it is 
downloaded and built.  The default name is C<_alien>.

=cut

sub build_prop_build_dir
{
  my($self) = @_;
  my $dir = $self->{init}->{build_dir} || $BUILD_DIR;
  mkdir($dir) || die "unable to create $dir $!"
    unless -d $dir;
  local $CWD = $dir;
  $CWD;
}

=head2 dest_dir

If set to true (the default is false), do a "double staged destdir" install.

TODO: needs FAQ

=cut

sub build_prop_dest_dir
{
  my($self) = @_;
  $self->{init}->{dest_dir} ? _catdir($self->build_dir, 'destdir') : undef;
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

sub build_prop_env
{
  my($self) = @_;
  
  my %env;
  local $ENV{PATH} = $ENV{PATH};
  my $config = $self->{env_log} = Alien::Builder::EnvLog->new;
  
  foreach my $mod (keys %{ $self->bin_requires }) {
    my $version = $self->bin_requires->{$mod};
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
    
    local $CWD = $self->build_dir;
      
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
  
  if(my $value = $self->dest_dir)
  {
    $env{DESTDIR} = $value;
    $config->set( DESTDIR => $value );
  }
    
  foreach my $key (sort keys %{ $self->{init}->{env} || {} })
  {
    my $value = $self->interpolator->interpolate( $self->{init}->{env}->{$key} );
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
    
  $config->write_log($self->build_dir);
    
  \%env;
}

=head2 extractor

The extractor class.  This is 
L<Alien::Builder::Extractor::Plugin::ArchiveTar> by default.

=cut

sub build_prop_extractor
{
  my($self) = @_;
  $self->_class(
    $self->{init}->{extractor},
    'Alien::Builder::Extractor::Plugin',
    'ArchiveTar',
    'extract',
  );
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

sub build_prop_ffi_name
{
  my($self) = @_;
  my $name = $self->{init}->{ffi_name};
  unless(defined $name)
  {
    $name = $self->name;
    $name =~ s/^lib//;
    $name =~ s/-[0-9\.]+$//;
  }
  $name;
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

sub build_prop_helper
{
  my($self) = @_;
  my %helper = %{ $self->{init}->{helper} || {} };
  $helper{pkg_config} = 'Alien::Builder::PkgConfig->pkg_config_command'
    unless defined $helper{pkg_config};
  \%helper;
}

=head2 inline_auto_include

Array reference containing the list of header files to be used 
automatically by L<Inline::C> and L<Inline::CPP>.

=cut

sub build_prop_inline_auto_include
{
  my($self) = @_;
  my @iai = @{ $self->{init}->{inline_auto_include} || [] };
  \@iai;
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

sub build_prop_install_commands
{
  my($self) = @_;
  weaken $self;
  my @commands = @{ $self->{init}->{install_commands} || [ 'make install' ] };
  Alien::Builder::CommandList->new(
    \@commands,
    interpolator => $self->interpolator,
    system       => sub { $self->_alien_do_system_for_command_list(@_) },
  );
}

=head2 interpolator

The interpolator class.  This is 
L<Alien::Builder::Interpolator::Default> by default.

=cut

sub build_prop_interpolator
{
  my($self) = @_;
  my($class) = $self->_class(
    $self->{init}->{interpolator},
    'Alien::Builder::Interpolator',
    'Default'
  );
  $class->new(
    vars => {
      # for compat with AB::MB we do on truthiness,
      # not definedness
      n => $self->name,
      s => $self->prefix,
      c => $self->_autoconf_configure,
    },
    helpers => $self->helper,
  );
}

=head2 isolate_dynamic

If set to true (the default), then dynamic libraries will be moved from 
the lib directory to a separate dynamic directory. This makes them 
available for FFI modules (such as L<FFI::Platypus>, or L<FFI::Raw>), 
while preferring static libraries when creating C<XS> extensions.

=cut

sub build_prop_isolate_dynamic
{
  my($self) = @_;
  my $id = $self->{init}->{isolate_dynamic};
  $id = 1 unless defined $id;
  $id;
}

=head2 msys

On windows wrap build and install commands in an C<MSYS> environment using 
L<Alien::MSYS>. This option will automatically add L<Alien::MSYS> as a build 
requirement when building on Windows.

=cut

sub build_prop_msys
{
  my($self) = @_;
  (!!$self->{init}->{msys}) || $self->_autoconf;
}

=head2 name

The name of the primary library which will be provided.  This should be 
in the form to be passed to C<pkg-config>.

=cut

sub build_prop_name
{
  my($self) = @_;
  $self->{init}->{name} || '';
}

=head2 prefix

The install prefix to use.  If you are using one of the MakeMaker or
Module::Build interfaces, then this will likely be specified for you.

=cut

sub build_prop_prefix
{
  my($self) = @_;
  $self->{init}->{prefix} || '/usr/local';
}

=head2 provides_cflags

=head2 provides_libs

These parameters, if specified, augment the information found by 
C<pkg-config>. If no package config data is found, these are used to 
generate the necessary information. In that case, if these are not 
specified, they are attempted to be created from found shared-object 
files and header files. They both are empty by default.

=cut

sub build_prop_provides_cflags
{
  my($self) = @_;
  $self->{init}->{provides_cflags};
}

sub build_prop_provides_libs
{
  my($self) = @_;
  $self->{init}->{provides_libs};
}

=head2 retriever

An array reference that specifies the retrieval of your libraries
archive.  Usually this is a URL, followed by a sequence of one or
more selection specifications.  For example for a simple directory
that contains multiple tarballs:

 # finds the newest version of http://example.com/dist/libfoo-$VERSION.tar.gz
 my $builder = Alien::Builder->new(
   retriever => [ 
     'http://example.com/dist/' => 
     { pattern => qr{^libfoo-[0-9]+\.[0-9]+\.tar\.gz$} },
   ],
 );

If you have multiple directory hierarchy, you can handle this by
extra selection specifications:

 # finds the newest version of http://example.com/dist/$VERSION/libfoo-$VERSION.tar.gz
 my $builder = Alien::Builder->new(
   retriever => [ 
     'http://example.com/dist/' => 
     { pattern => qr{^v[0-9]+$} },
     { pattern => qr{^libfoo-[0-9]+\.[0-9]+\.tar\.gz$} },
   ],
 );

=cut

sub build_prop_retriever
{
  my($self) = @_;
  $self->retriever_class->new(@{ $self->{init}->{retriever} || [] });
}

=head2 retriever_class

The class used to do the actual retrieval.  This allows you to write your own
custom retriever if the build in version does not provide enough functionality.

=cut

sub build_prop_retriever_class
{
  my($self) = @_;
  $self->_class($self->{init}->{retriever_class}, 'Alien::Builder::Retriever');
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

sub build_prop_test_commands
{
  my($self) = @_;
  weaken $self;
  my @commands = @{ $self->{init}->{test_commands} || [] };
  Alien::Builder::CommandList->new(
    \@commands,
    interpolator => $self->interpolator,
    system       => sub { $self->_alien_do_system_for_command_list(@_) },
  );
}

=head2 version_check

A command to run to check the version of the library installed on the 
system.  The default is C<pkg-config --modversion %n>.

=cut

sub build_prop_version_check
{
  my($self) = @_;
  $self->{init}->{version_check} || '%{pkg_config} --modversion %n';
}

=head1 METHODS

=head2 action_download

 $builder->action_download;

Action that downloads the archive.

=cut

sub action_download
{
  my($self) = @_;
  if($self->install_type eq 'share')
  {
    $self->{config}->{working_download} = $self->retriever->retrieve->copy_to($self->build_dir);
  }
  $self;
}

=head2 action_extract

 $builder->action_extract;

Action that extracts the archive.

=cut

sub action_extract
{
  my($self) = @_;
  if($self->install_type eq 'share')
  {
    $self->{config}->{working_dir} = $self->extractor->extract($self->{config}->{working_download}, $self->build_dir);
  }
  $self;
}

=head2 action_build

 $builder->action_build;

Action that builds the library.  Executes commands as specified by L</build_commands>.

=cut

sub action_build
{
  my($self) = @_;
  if($self->install_type eq 'share')
  {
    local $CWD = $self->{config}->{working_dir};
    print "+ cd $CWD\n";
    $self->build_commands->execute;
  }
  $self;
}

=head2 action_test

 $builder->action_test;

Action that tests the library.  Executes commands as specified by L</test_commands>.

=cut

sub action_test
{
  my($self) = @_;
  if($self->install_type eq 'share')
  {
    local $CWD = $self->{config}->{working_dir};
    print "+ cd $CWD\n";
    $self->test_commands->execute;
  }
  $self;
}

=head2 action_install

 $builder->action_install;

Action that installs the library.  Executes commands as specified by L</install_commands>.

=cut

sub action_install
{
  my($self) = @_;
  if($self->install_type eq 'share')
  {
    local $CWD = $self->{config}->{working_dir};
    print "+ cd $CWD\n";
    $self->install_commands->execute;
    $self->_postinstall_load_pkgconfig;
    $self->_postinstall_relocation_fixup;
    $self->_postinstall_isolate_dynamic;
  }
  unless(-d $self->prefix)
  {
    require File::Path;
    File::Path::mkpath($self->prefix, 0, 0755);
  }
  $self->save(File::Spec->catfile($self->prefix, 'alien_builder.json'));
  $self;
}

#sub action_postinstall
#{
#  my($self) = @_;
#  return unless $self->install_type eq 'share';
#  
#  # QUESTION:
#  # - maybe this should be in Alien::Builder::MM instead.
#  
#  # TODO:
#  # - populate $builder->{config}->{pkgconfig} (see AB::MB->alien_load_pkgconfig)
#  
#  # - create Alien::Foo::Install::Files.pm (here or elsewhere?)
#}

=head2 action_fake

 $builder->action_fake;

Action that prints the commands that I<would> be executed during the build, test and install
stages.

=cut

sub action_fake
{
  my($self) = @_;
  my $cwd = $self->{config}->{working_dir};
  foreach my $stage (qw( build test install ))
  {
    my $method = "${stage}_commands";
    my $cl = $self->$method;
    next if $cl->is_empty;
    print "# make alien_$stage\n";
    print "+ cd $cwd\n";
    foreach my $cmd ($cl->interpolate)
    {
      print "+ @{$cmd}\n";
    }
  }
}

=head2 alien_build_requires

 my $hash = $builder->alien_build_requires

Returns hash of build requirements.

=cut

sub alien_build_requires
{
  my($self) = @_;
  $self->{build_requires};
}

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
  return eval {
    my %result = $self->alien_do_system($self->version_check, { verbose => 0 });
    ($result{success} && $result{stdout}) || 0;
  };
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
  # TODO: actually use this (?) it isn't actually being called ever yet.
  #       though I am not entirely sure it needs to be.
  # TODO: try to get the version number from pkgconfig
  # TODO: try to determine version number from directory (foo-1.00 should imply version 1.00)
  # TODO: populate $builder->{config}->{version};
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
  my $opts = ref $args[-1] ? pop @args : { verbose => 1, interpolate => 1 };
  
  local %ENV = %ENV;
  foreach my $key (sort keys %{ $self->env })
  {
    my $value = $self->env->{$key};
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

  @args = map { $self->interpolator->interpolate($_) } @args
    unless $opts->{interplate};
  
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

=head2 save

 $builder->save;

Saves the state information of that L<Alien::Builder> instance.

=cut

sub save
{
  my($self, $filename) = @_;
  $filename ||= 'alien_builder.json';
  my $fh;
  open($fh, '>', $filename) || die "unable to write $filename $!";
  print $fh JSON::PP->new->convert_blessed(1)->encode({ init => $self->{init}, config => $self->{config}, class => ref($self), alien => $self->{alien} });
  close $fh;
  $self;
}

=head2 restore

 Alien::Builder->restore;

Restores an L<Alien::Builder> instance from the state information saved by L</save>.

=cut

sub restore
{
  my($class, $filename) = @_;
  $filename ||= 'alien_builder.json';
  my $fh;
  open($fh, '<', $filename) || die "unable to read $filename $!";
  my $payload = JSON::PP->new
    ->filter_json_object(sub {
      my($object) = @_;
      my $class = delete $object->{'__CLASS__'};
      return unless $class;
      bless $object, $class;
    })->decode(do { local $/; <$fh> });
  close $fh;
  __PACKAGE__->_class($payload->{class});
  my $self = $payload->{class}->new(%{ $payload->{init} });
  $self->{config} = $payload->{config};
  $self;
}

# Private properties

sub _alien_do_system_for_command_list
{
  my($self, @args) = @_;
  print "+ @args\n";
  my %r = $self->alien_do_system(@args, { interpolate => 0 });
  die "command failed: $r{command}" unless $r{success};
}

sub _autoconf
{
  my($self) = @_;
  $self->{autoconf} ||= do {
    !!grep /(?<!\%)\%c/, 
      map { ref $_ ? @$_ : $_ }
      map { $_->raw }
      map { $self->$_ }
      qw( build_commands install_commands test_commands );
  };
}

sub _autoconf_configure
{
  my($self) = @_;
  my $configure = $OS eq 'MSWin32' ? 'sh configure' : './configure';
  $configure .= ' --with-pic' if $self->autoconf_with_pic;
  $configure;
}

sub _env_log
{
  my($self) = @_;
  $self->env;
  $self->{env_log};
}

sub build_prop_install_type
{
  my($self) = @_;
  
  $self->{config}->{install_type} ||= do {
  
    if(($ENV{ALIEN_INSTALL_TYPE} || 'system') eq 'system')
    {
      if(my $version = $self->alien_check_installed_version)
      {
        $self->{config}->{version} = $version;
        return $self->{config}->{install_type} = 'system';
      }
    }
  
    if(($ENV{ALIEN_INSTALL_TYPE} || 'share') eq 'share')
    {
      return $self->{config}->{install_type} = 'share';
    }
  
    die "you requested a system install type, but the required package was not found.";
  };
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

sub _postinstall_load_pkgconfig
{
  my($self) = @_;
  
  my %pc_objects;
  
  File::Find::find(sub {
    return unless /\.pc$/ && -f;
    
    my $filename = File::Spec->catfile($File::Find::dir, $_);
    my $pc = Alien::Builder::PkgConfig->new($filename);
    $pc_objects{$pc->{package}} = $pc;
    
  }, $self->prefix);
  
  $self->{config}->{pkgconfig} = \%pc_objects;
  
  $self;
}

# this is in the wrong place.  The fixup needs to be made
# once the files have been copied to their final location
# I think... no relocatable dirs supported then.
sub _postinstall_relocation_fixup
{
  my($self) = @_;
  
  # so far relocation fixup is only needed on OS X
  return unless $^O eq 'darwin';
  
  File::Find::find(sub {
    return unless /\.dylib$/;
    
    # save the original mode and make it writable
    my $mode = (stat $File::Find::name)[2];
    chmod 0755, $File::Find::name unless -w $File::Find::name;
    
    my @cmd = (
      'install_name_tool',
      '-id' => $File::Find::name,
      $File::Find::name,
    );
    system @cmd;
    
    # restore the original permission mode
    chmod $mode, $File::Find::name;
  
  }, $self->prefix);
}

sub _postinstall_isolate_dynamic
{
  my($self) = @_;
  
  local $CWD = $self->prefix;
  
  mkdir 'dynamic' unless -d 'dynamic';
  foreach my $dir (qw( bin lib ))
  {
    next unless -d $dir;
    opendir(my $dh, $dir);
    my @dlls = grep { /\.so/ || /\.(dylib|bundle|la|dll|dll\.a)$/ } grep !/^\./, readdir $dh;
    closedir $dh;
    foreach my $dll (@dlls)
    {
      require File::Copy;
      my $from = File::Spec->catfile($dir, $dll);
      my $to   = File::Spec->catfile('dynamic', $dll);
      unlink $to if -e $to;
      File::Copy::move($from, $to);
    }
  }
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
