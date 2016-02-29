# Alien::Builder [![Build Status](https://secure.travis-ci.org/plicease/Alien-Builder.png)](http://travis-ci.org/plicease/Alien-Builder) [![Build status](https://ci.appveyor.com/api/projects/status/1gxa3q2y8q5ts6p6/branch/master?svg=true)](https://ci.appveyor.com/project/plicease/Alien-Builder/branch/master)

Base classes for Alien builder modules

# SYNOPSIS

Create a simple instance:

    use Alien::Builder;

    my $ab = Alien::Builder->new(
      name => 'foo',
      retreiver_start => 'http://example.com/dist',
      retriever_spec => [
        { pattern => qr{^libfoo-(([0-9]\.)*[0-9]+)\.tar\.gz$} },
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

Deploy with [ExtUtils::MakeMaker](https://metacpan.org/pod/ExtUtils::MakeMaker) (see [Alien::Builder::MM](https://metacpan.org/pod/Alien::Builder::MM) for more details):

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

Deploy with [Dist::Zilla](https://metacpan.org/pod/Dist::Zilla):

    [AlienBuilder]
    name = foo
    retreiver_start = http://ftp.example.com/dist/
    retriever_spec.0.pattern = ^foo-(([0-9]+\.)*[0-9]+)\.tar\.gz$
    build_commands = %c --prefix=%s
    build_commands = make
    install_commands = make install

Deploy with [Module::Build](https://metacpan.org/pod/Module::Build), see [Alien::Base::ModuleBuild](https://metacpan.org/pod/Alien::Base::ModuleBuild).

# DESCRIPTION

**WARNING**: this interface is **EXPERIMENTAL**.  If you need something stable right
now, use [Alien::Base::ModuleBuild](https://metacpan.org/pod/Alien::Base::ModuleBuild).

The purpose of this class is to provide a generic builder/installer that can be used
by [ExtUtils::MakeMaker](https://metacpan.org/pod/ExtUtils::MakeMaker) and [Module::Build](https://metacpan.org/pod/Module::Build) derivatives for creating [Alien](https://metacpan.org/pod/Alien)
distributions.  Basically this class provides the generic machinery used during the
configure and build stages, and [Alien::Base](https://metacpan.org/pod/Alien::Base) can be used at runtime once the [Alien](https://metacpan.org/pod/Alien)
module is already installed.  It could also be used independently of an installer to
install a library.

The design goals of this library are to make the "easy" things easy, and hard things
possible.  For this discussion, "easy" means build and install libraries that use
the standard GNU style autotools, or generic Makefiles.  Harder things may require
writing Perl code, and you can accomplish this by subclassing [Alien::Builder](https://metacpan.org/pod/Alien::Builder).

# CONSTRUCTOR

## new

    my $builder = Alien::Builder->new(%properties);

Create a new instance of [Alien::Builder](https://metacpan.org/pod/Alien::Builder).

# PROPERTIES

At the minimum you will want to define a ["retriever"](#retriever) specification.
Unless your tool or library uses GNU autotools style interface (that is
it is installed with something like "./configure && make && make install")
you will need to also provide build and install commands with the
["build\_commands"](#build_commands) and ["install\_commands"](#install_commands) properties.  Depending on
the complexity of your tool or library you may need to specify additional
properties.

Properties are read-only and can only be specified when passing them into
["new"](#new) as arguments.  They can be accessed after the [Alien::Builder](https://metacpan.org/pod/Alien::Builder)
object is created using accessor methods of the same name.

    my $builder = Alien::Builder->new( arch => 1 );
    $builder->arch; # is 1

## arch

Install module into an architecture specific directory. This is off by 
default, unless `$ENV{ALIEN_ARCH}` is true. Most Alien distributions 
will be installing binary code. If you are an integrator where the 
`@INC` path is shared by multiple Perls in a non-homogeneous 
environment you can set `$ENV{ALIEN_ARCH}` to 1 and Alien modules will 
be installed in architecture specific directories.

## autoconf\_with\_pic

Add `--with-pic` option to autoconf style configure script when called. 
This is the default, and normally a good practice. Normally autoconf 
will ignore this and any other options that it does not recognize, but 
some non-autoconf `configure` scripts may complain.

## bin\_requires

Hash reference of modules (keys) and versions (values) that specifies 
[Alien](https://metacpan.org/pod/Alien) modules that provide binary tools that are required to build.  
Any [Alien::Base](https://metacpan.org/pod/Alien::Base) that includes binaries should work.  Also supported 
are [Alien::MSYS](https://metacpan.org/pod/Alien::MSYS), [Alien::CMake](https://metacpan.org/pod/Alien::CMake), [Alien::TinyCC](https://metacpan.org/pod/Alien::TinyCC) and 
[Alien::Autotools](https://metacpan.org/pod/Alien::Autotools).  These become build time requirements for your 
module if [Alien::Builder](https://metacpan.org/pod/Alien::Builder) determines that a source code build is 
required.

## build\_commands

An array reference of commands used to build the library in the 
directory specified in ["build\_dir"](#build_dir).  Each command is first passed 
through the [command interpolation engine](#command-interpolation), so 
any variable or helper provided may be used.  The default is tailored to 
the GNU toolchain (that is autoconf and `make`); it is
`[ '%c --prefix=%s', 'make' ]`.  Each command may be either a string or 
an array reference.  If the array reference form is used then the 
multiple argument form of system is used.

## build\_dir

The name of the folder which will house the library where it is 
downloaded and built.  The default name is `_alien`.

## dest\_dir

If set to true (the default is false), do a "double staged destdir" install.

TODO: needs FAQ

## env

Environment overrides.  Allows you to set environment variables as a 
hash reference that will override environment variables.  You can use 
the same interpolated escape sequences and helpers that commands use.  
Set to `undef` to remove the environment variable.

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

## extractor

The extractor class.  This is 
[Alien::Builder::Extractor::Plugin::ArchiveTar](https://metacpan.org/pod/Alien::Builder::Extractor::Plugin::ArchiveTar) by default.

## ffi\_name

The name of the shared library for use with FFI.  Provided for 
situations where the shared library name cannot be determined from the 
`pkg-config` name specified as ["name"](#name).  For example, `libxml2` has a 
`pkg-config` name of `libxml-2.0`, but a shared library name of 
`xml2`.  By default ["name"](#name) is used with any `lib` prefix removed. 
For example if you specify a ["name"](#name) of `libarchive`, ["ffi\_name"](#ffi_name) 
will be `archive`.

## helper

Provide helpers to generate commands or arguments at build or install 
time. This property is a hash reference. The keys are the helper names 
and the values are strings containing Perl code that will be evaluated 
and interpolated into the command before execution. Because helpers are 
only needed when building a package from the source code, any dependency 
may be specified as an ["bin\_requires"](#bin_requires). For example:

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

One helper that you get for free is `%{pkg_config}`, which will be the 
`pkg-config` implementation chosen by [Alien::Builder](https://metacpan.org/pod/Alien::Builder).  This will 
either be the "real" `pkg-config` provided by the operating system 
(preferred), or [PkgConfig](https://metacpan.org/pod/PkgConfig), the pure perl implementation found on 
CPAN.

## inline\_auto\_include

Array reference containing the list of header files to be used 
automatically by [Inline::C](https://metacpan.org/pod/Inline::C) and [Inline::CPP](https://metacpan.org/pod/Inline::CPP).

## install\_commands

An array reference of commands used to install the library in the 
directory specified in ["build\_dir"](#build_dir).  Each command is first passed 
through the [command interpolation engine](#command-interpolation), so 
any variable or helper provided may be used.  The default is tailored to 
the GNU toolchain (that is autoconf and `make`); it is
`[ 'make install' ]`.  Each command may be either a string or an array 
reference.  If the array reference form is used then the multiple 
argument form of system is used.

## interpolator

The interpolator class.  This is 
[Alien::Builder::Interpolator::Default](https://metacpan.org/pod/Alien::Builder::Interpolator::Default) by default.

## isolate\_dynamic

If set to true (the default), then dynamic libraries will be moved from 
the lib directory to a separate dynamic directory. This makes them 
available for FFI modules (such as [FFI::Platypus](https://metacpan.org/pod/FFI::Platypus), or [FFI::Raw](https://metacpan.org/pod/FFI::Raw)), 
while preferring static libraries when creating `XS` extensions.

## msys

On windows wrap build and install commands in an `MSYS` environment using 
[Alien::MSYS](https://metacpan.org/pod/Alien::MSYS). This option will automatically add [Alien::MSYS](https://metacpan.org/pod/Alien::MSYS) as a build 
requirement when building on Windows.

## name

The name of the primary library which will be provided.  This should be 
in the form to be passed to `pkg-config`.

## prefix

The install prefix to use.  If you are using one of the MakeMaker or
Module::Build interfaces, then this will likely be specified for you.

## provides\_cflags

## provides\_libs

These parameters, if specified, augment the information found by 
`pkg-config`. If no package config data is found, these are used to 
generate the necessary information. In that case, if these are not 
specified, they are attempted to be created from found shared-object 
files and header files. They both are empty by default.

## retriever

The class used to do the actual retrieval.  This allows you to write your own
custom retriever if the build in version does not provide enough functionality.

## retriever\_spec

An array reference that specifies the retrieval of your libraries
archive.  This is a sequence of one or more selection specifications.
For example for a simple directory that contains multiple tarballs:

    # finds the newest version of http://example.com/dist/libfoo-$VERSION.tar.gz
    my $builder = Alien::Builder->new(
      retriever_start => 'http://example.com',
      retriever_spec => [ 
        { pattern => qr{^libfoo-[0-9]+\.[0-9]+\.tar\.gz$} },
      ],
    );

If you have multiple directory hierarchy, you can handle this by
extra selection specifications:

    # finds the newest version of http://example.com/dist/$VERSION/libfoo-$VERSION.tar.gz
    my $builder = Alien::Builder->new(
      retriever_start => 'http://example.com',
      retriever_spec => [ 
        { pattern => qr{^v[0-9]+$} },
        { pattern => qr{^libfoo-[0-9]+\.[0-9]+\.tar\.gz$} },
      ],
    );

## retriever\_start

URL or hash reference to indicate the start of the retrieval process.

## test\_commands

An array reference of commands used to test the library in the directory 
specified in ["build\_dir"](#build_dir).  Each command is first passed through the 
[command interpolation engine](#command-interpolation), so any variable 
or helper provided may be used.  The default is not to run any tests; it 
is `[]`. Each command may be either a string or an array reference.  If 
the array reference form is used then the multiple argument form of 
system is used.

## version\_check

A command to run to check the version of the library installed on the 
system.  The default is `pkg-config --modversion %n`.

# METHODS

## action\_download

    $builder->action_download;

Action that downloads the archive.

## action\_extract

    $builder->action_extract;

Action that extracts the archive.

## action\_build

    $builder->action_build;

Action that builds the library.  Executes commands as specified by ["build\_commands"](#build_commands).

## action\_test

    $builder->action_test;

Action that tests the library.  Executes commands as specified by ["test\_commands"](#test_commands).

## action\_install

    $builder->action_install;

Action that installs the library.  Executes commands as specified by ["install\_commands"](#install_commands).

## action\_fake

    $builder->action_fake;

Action that prints the commands that _would_ be executed during the build, test and install
stages.

## alien\_build\_requires

    my $hash = $builder->alien_build_requires

Returns hash of build requirements.

## alien\_check\_installed\_version

    my $version = $builder->alien_check_installed_version;

This function determines if the library is already installed as part of 
the operating system, and returns the version as a string. If it can't 
be detected then it should return empty list.

The default implementation relies on `pkg-config`, but you will 
probably want to override this with your own implementation if the 
package you are building does not use `pkg-config`.

## alien\_check\_built\_version

    my $version = $builder->alien_check_built_version;

This function determines the version of the library after it has been 
built from source. This function only gets called if the operating 
system version can not be found and the package is successfully built.

The default implementation relies on `pkg-config`, and other heuristics, 
but you will probably want to override this with your own implementation 
if the package you are building does not use `pkg-config`.

When this method is called, the current working directory will be the 
build root.

If you see an error message like this:

    Library looks like it installed, but no version was determined

After the package is built from source code then you probably need to 
provide an implementation for this method.

## alien\_do\_system

    my %result = $builder->alien_do_system($cmd);
    my %result = $builder->alien_do_system(@cmd);

Executes the given command using either the single argument or multiple 
argument form.  Before executing the command, it will be interpolated 
using the [command interpolation engine](#command-interpolation).

Returns a set of key value pairs including `stdout`, `stderr`, 
`success` and `command`.

## save

    $builder->save;

Saves the state information of that [Alien::Builder](https://metacpan.org/pod/Alien::Builder) instance.

## restore

    my $builder = Alien::Builder->restore;

Restores an [Alien::Builder](https://metacpan.org/pod/Alien::Builder) instance from the state information saved by ["save"](#save).

# ENVIRONMENT

## ALIEN\_ARCH

Setting this changes the default for ["arch"](#arch) above. If the module 
specifies its own ["arch"](#arch) then it will override this setting. Typically 
installing into an architecture specific directory is what you want to 
do, since most [Alien::Base](https://metacpan.org/pod/Alien::Base) based distributions provide architecture 
specific binary code, so you should consider carefully before installing 
modules with this environment variable set to `0`. This may be useful 
for integrators creating a single non-architecture specific `RPM`, 
`.dep` or similar package. In this case the integrator should ensure 
that the Alien package be installed with a system install\_type and use 
the system package.

## ALIEN\_INSTALL\_TYPE

Setting to `share` will ignore a system-wide installation and build a 
local version of the library.  Setting to `system` will only use a 
system-wide installation and die if it cannot be found.

# COMMAND INTERPOLATION

Before [Alien::Builder](https://metacpan.org/pod/Alien::Builder) executes system commands, or applies 
environment overrides, it replaces a few special escape sequences with 
useful data.  This is needed especially for referencing the full path to 
the appropriate install location before the path is known.  The 
available sequences are:

- `%{helper}`

    Evaluate the given helper, as provided by either the ["helper"](#helper) or 
    ["bin\_requires"](#bin_requires) property.  See [Alien::Base#alien\_helper](https://metacpan.org/pod/Alien::Base#alien_helper).

- `%c`

    Platform independent incantation for running autoconf `configure` 
    script.  On Unix systems this is `./configure`, on Windows this is
    `sh configure`.  On windows [Alien::MSYS](https://metacpan.org/pod/Alien::MSYS) is injected as a dependency 
    and all commands are executed in a `MSYS` environment.

- `%n`

    Shortcut for the name stored in ["name"](#name).  The default is:
    `pkg-config --modversion %n`

- `%s`

    The full path to the final installed location of the share directory. 
    This is where the library should install itself; for autoconf style 
    installs, this will look like `--prefix=%s`.

- `%v`

    Captured version of the original archive.

- `%x`

    The current Perl interpreter (similar to `$^X`).

- `%X`

    The current Perl interpreter using the Unix style path separator `/` 
    instead of native Windows `\`.

- `%%`

    A literal `%`.

# SEE ALSO

- [Alien::Base](https://metacpan.org/pod/Alien::Base)

    Runtime access to configuration determined by [Alien::Builder](https://metacpan.org/pod/Alien::Builder) and 
    build time.

- [Alien](https://metacpan.org/pod/Alien)

    The original [Alien](https://metacpan.org/pod/Alien) manifesto.

# AUTHOR

Author: Graham Ollis &lt;plicease@cpan.org>

Contributors:

David Mertens (run4flat)

Mark Nunberg (mordy, mnunberg)

Christian Walde (Mithaldu)

Brian Wightman (MidLifeXis)

Graham Ollis (plicease)

Zaki Mughal (zmughal)

mohawk2

Vikas N Kumar (vikasnkumar)

Flavio Poletti (polettix)

# COPYRIGHT AND LICENSE

This software is copyright (c) 2016 by Graham Ollis.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
