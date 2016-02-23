use strict;
use warnings;
use lib 'corpus/basic/lib';
use File::chdir;
use Alien::Builder;
use File::Temp qw( tempdir );
use Config;
use Test::More tests => 24;
use Capture::Tiny qw( capture );

$Alien::Builder::BUILD_DIR = tempdir( CLEANUP => 1 );

subtest 'simple' => sub {
  plan tests => 1;

  my $builder = eval { Alien::Builder->new };
  isa_ok $builder, 'Alien::Builder';

};

subtest 'autoconf' => sub {
  plan tests => 3;

  subtest default => sub {
    plan tests => 2;

    my $builder = Alien::Builder->new;
    ok !!$builder->_autoconf, '_autoconf is on';
    ok !!$builder->alien_prop_msys, '_msys is on';

  };

  subtest off => sub {
    plan tests => 2;

    my $builder = Alien::Builder->new(
      build_commands => [ 'something', 'other', 'than', 'autoconf' ],
    );

    ok !$builder->_autoconf, '_autoconf is off';
    ok !$builder->alien_prop_msys, '_msys is off';
  
  };
  
  subtest on => sub {
    plan tests => 2;
  
    subtest string => sub {
      plan tests => 2;
    
      my $builder = Alien::Builder->new(
        build_commands => [ 'something', '%c', 'here' ],
      );
    
      ok !!$builder->_autoconf, '_autoconf is on';
      ok !!$builder->alien_prop_msys, '_msys is on';
    };
    
    subtest list => sub {
      plan tests => 2;

      my $builder = Alien::Builder->new(
        build_commands => [ [ 'something', '%c', 'here' ] ],
      );
    
      ok !!$builder->_autoconf, '_autoconf is on';
      ok !!$builder->alien_prop_msys, '_msys is on';
    };
  
  };

};

subtest msys => sub {
  plan tests => 2;

  subtest on => sub {
    plan tests => 2;
    
    my $builder = Alien::Builder->new(
      build_commands => [ 'something', 'other', 'than', 'autoconf' ],
      msys => 1,
    );

    ok !$builder->_autoconf, '_autoconf is off';
    ok !!$builder->alien_prop_msys, '_msys is on';
    
  
  };

  subtest off => sub {
    plan tests => 2;
    
    my $builder = Alien::Builder->new(
      build_commands => [ 'something', 'other', 'than', 'autoconf' ],
      msys => 0,
    );

    ok !$builder->_autoconf, '_autoconf is off';
    ok !$builder->alien_prop_msys, '_msys is off';
    
  
  };

};

subtest bin_requires => sub {
  plan tests => 2;

  subtest 'unix like' => sub {
    plan tests => 2;
    local $Alien::Builder::OS = 'linux';
    
    subtest default => sub {
      plan tests => 1;
    
      my $builder = Alien::Builder->new;
      is_deeply $builder->alien_prop_bin_requires, {}, 'bin requires is empty';
    
    };
    
    subtest 'some values' => sub {
      plan tests => 1;

      my $builder = Alien::Builder->new(
        bin_requires => {
          'Alien::Foo' => 0,
          'Alien::Bar' => '1.234',
        },
      );
      is_deeply $builder->alien_prop_bin_requires, {
        'Alien::Foo' => 0,
        'Alien::Bar' => '1.234',
      }, 'matches';

    };
  };
  
  subtest 'windows' => sub {
    plan tests => 3;
    local $Alien::Builder::OS = 'MSWin32';

    subtest default => sub {
      plan tests => 1;
    
      my $builder = Alien::Builder->new;
      is_deeply $builder->alien_prop_bin_requires, { 'Alien::MSYS' => 0 }, 'bin requires has Alien::MSYS';
    
    };

    subtest 'some values' => sub {
      plan tests => 1;

      my $builder = Alien::Builder->new(
        bin_requires => {
          'Alien::Foo' => 0,
          'Alien::Bar' => '1.234',
        },
      );
      is_deeply $builder->alien_prop_bin_requires, {
        'Alien::Foo' => 0,
        'Alien::Bar' => '1.234',
        'Alien::MSYS' => 0,
      }, 'matches';

    };

    subtest 'some values sans MSYS' => sub {
      plan tests => 1;

      my $builder = Alien::Builder->new(
        build_commands => [],
        bin_requires => {
          'Alien::Foo' => 0,
          'Alien::Bar' => '1.234',
        },
      );
      is_deeply $builder->alien_prop_bin_requires, {
        'Alien::Foo' => 0,
        'Alien::Bar' => '1.234',
      }, 'matches';

    };
  };

};

subtest env_log => sub {
  plan tests => 1;

  subtest default => sub {
    plan tests => 1;

    my $builder = Alien::Builder->new;
    isa_ok $builder->_env_log, 'Alien::Builder::EnvLog';

  };

};

subtest 'cat file and dir' => sub {
  plan tests => 2;

  my $root = tempdir( CLEANUP => 1 );

  unlike Alien::Builder::_catfile( $root, qw( foo bar baz ) ), qr{\\}, 'no \\ in file';
  unlike Alien::Builder::_catdir( $root, qw( foo bar baz ) ), qr{\\}, 'no \\ in dir';

};

subtest 'filter_defines' => sub {
  plan tests => 1;
  
  is Alien::Builder::_filter_defines("-I/foo -DFOO=1 -L/bar   -lbaz"), '-I/foo -L/bar -lbaz', 'filters out define';

};

subtest 'interpolator' => sub {
  plan tests => 3;

  subtest default => sub {
    plan tests => 2;
    my $intr = Alien::Builder->new->alien_prop_interpolator;
    isa_ok $intr, 'Alien::Builder::Interpolator::Default';
    isa_ok $intr, 'Alien::Builder::Interpolator';
  };
  
  subtest 'fully qualified' => sub {
    plan tests => 1;
    my $intr = Alien::Builder->new(
      interpolator => 'Alien::Builder::Interpolator::Foo',
    )->alien_prop_interpolator;
    isa_ok $intr, 'Alien::Builder::Interpolator::Foo';
  };

  subtest 'abbreviated' => sub {
    plan tests => 1;
    my $intr = Alien::Builder->new(
      interpolator => 'Foo',
    )->alien_prop_interpolator;
    isa_ok $intr, 'Alien::Builder::Interpolator::Foo';
  };

};

subtest 'extractor' => sub {
  plan tests => 3;

  subtest default => sub {
    plan tests => 2;
    my $xtor = Alien::Builder->new->alien_prop_extractor;
    is $xtor, 'Alien::Builder::Extractor::Plugin::ArchiveTar';
    ok $xtor->can('extract'), 'can extract';
  };

  subtest 'fully qualified' => sub {
    plan tests => 2;
    my $xtor = Alien::Builder->new( extractor => 'Alien::Builder::Extractor::Plugin::Foo' )->alien_prop_extractor;
    is $xtor, 'Alien::Builder::Extractor::Plugin::Foo';
    ok $xtor->can('extract'), 'can extract';
  };

  subtest 'abbreviated' => sub {
    plan tests => 2;
    my $xtor = Alien::Builder->new( extractor => 'Foo' )->alien_prop_extractor;
    is $xtor, 'Alien::Builder::Extractor::Plugin::Foo';
    ok $xtor->can('extract'), 'can extract';
  };
  
};

subtest 'env' => sub {
  plan tests => 4;

  subtest default => sub {
    local $Alien::Builder::OS = 'linux';
  
    my $builder = Alien::Builder->new;

    my %env = %{ $builder->alien_prop_env };
    
    my $config_site = delete $env{CONFIG_SITE};
    
    is_deeply \%env, {}, 'nothing other than CONFIG_SITE';
    
    ok -s $config_site, "$config_site is not empty";
    
    note do { open my $fh, '<', $config_site; <$fh> };
  
  };
  
  subtest 'without autoconf' => sub {

    local %ENV = %ENV;
    delete $ENV{CONFIG_SITE};
  
    my $builder = Alien::Builder->new(
      build_commands => [],
    );
    
    is_deeply $builder->alien_prop_env, {}, 'empty env';
  
  };
  
  subtest bin_requires => sub {
  
    my @tests = (
      [ 'MSYS' => '/some/msys/path/bin' ],
      [ 'Autotools' => '/some/ac/path/bin', '/some/am/path/bin', '/some/lt/path/bin' ],
      [ 'Bar' => '/some/bar/path/bin' ],
      [ 'Foo' => '/some/foo/path/bin' ],
      [ 'TinyCC' => '/some/tcc/path/bin' ],
    );
    
    plan tests => 3 + scalar @tests;
    
    foreach my $test (@tests)
    {
      my $name = 'Alien::' . shift @$test;
      subtest $name => sub {
        plan tests => scalar @$test;
        my $builder = Alien::Builder->new(
          bin_requires => {
            $name => 0
          },
        );
        my %path = map { $_ => 1 } split $Config{path_sep}, $builder->alien_prop_env->{PATH};
        ok $_, "$_ is in PATH" for @$test;
      };
    }
    
    # TODO: support Alien::CMake
    # probably by just adding bin_dir interface
    
    subtest 'Alien::Bogus' => sub {
    
      plan tests => 1;
      
      my $builder = Alien::Builder->new( bin_requires => { 'Alien::Bogus' => 0 } );
      
      eval { $builder->alien_prop_env };
      like $@, qr{Bogus\.pm}, 'dies with message';
    
    };
    
    subtest 'Alien::Foo 0.05' => sub {
      plan tests => 1;

      my $builder = Alien::Builder->new( bin_requires => { 'Alien::Foo' => '0.05' } );
      
      eval { $builder->alien_prop_env };
      is $@, '', 'no crash';
      note $@ if $@;
    };

    subtest 'Alien::Foo 1.05' => sub {
      plan tests => 1;

      my $builder = Alien::Builder->new( bin_requires => { 'Alien::Foo' => '1.05' } );
      
      eval { $builder->alien_prop_env };
      like $@, qr{Alien::Foo}, 'dies with message';
    };
    
  };
  
  subtest overrides => sub {
    plan tests => 2;
  
    my $builder = Alien::Builder->new(
      interpolator => 'My::Intr',
      env => {
        FOO => '%f',
        BAR => undef,
      },
    );
    
    is $builder->alien_prop_env->{FOO}, 'foo', 'FOO=foo';
    is $builder->alien_prop_env->{BAR}, undef, 'BAR=undef';
  
  };

};

subtest name => sub {
  plan tests => 2;

  subtest default => sub {
    plan tests => 1;
  
    my $builder = Alien::Builder->new;
    
    is $builder->alien_prop_interpolator->interpolate('%n'), '', '%n is empty string';
  
  };
  
  subtest 'with value' => sub {
    plan tests => 1;

    my $builder = Alien::Builder->new( name => 'foo' );
    
    is $builder->alien_prop_interpolator->interpolate('%n'), 'foo', '%n is foo'

  };

};

subtest '%c' => sub {

  subtest default => sub {
  
    subtest 'unix like' => sub {
      local $Alien::Builder::OS = 'linux';
      my $builder = Alien::Builder->new;  
      is $builder->alien_prop_interpolator->interpolate('%c'), './configure --with-pic', 'is ./configure --with-pic';
    };
    
    subtest 'windows' => sub {
      local $Alien::Builder::OS = 'MSWin32';
      my $builder = Alien::Builder->new;  
      is $builder->alien_prop_interpolator->interpolate('%c'), 'sh configure --with-pic', 'is sh configure --with-pic';
    };
  
  };


};

subtest helper => sub {
  plan tests => 2;

  my $builder = Alien::Builder->new(
    helper => { foo => '"abc" . "def"' },
  );
  
  my $string = $builder->alien_prop_interpolator->interpolate('%{foo}');
  is $string, 'abcdef', 'used heler';

  my $pkg_config = $builder->alien_prop_interpolator->interpolate('%{pkg_config}');
  isnt $pkg_config, '', "pkg_config = $pkg_config"

};

subtest build_commands => sub {
  plan tests => 2;
  my $builder = Alien::Builder->new;
  isa_ok $builder->alien_prop_build_commands, 'Alien::Builder::CommandList';
  is_deeply [$builder->alien_prop_build_commands->raw], [['%c --prefix=%s'],['make']];
};

subtest install_commands => sub {
  plan tests => 2;
  my $builder = Alien::Builder->new;
  isa_ok $builder->alien_prop_install_commands, 'Alien::Builder::CommandList';
  is_deeply [$builder->alien_prop_install_commands->raw], [['make install']];
};

subtest test_commands => sub {
  my $builder = Alien::Builder->new;
  isa_ok $builder->alien_prop_test_commands, 'Alien::Builder::CommandList';
  is_deeply [$builder->alien_prop_test_commands->raw], [];
};

subtest arch => sub {
  plan tests => 3;

  delete $ENV{ALIEN_ARCH};

  subtest default => sub {
    plan tests => 1;
    my $builder = Alien::Builder->new;
    is !!$builder->alien_prop_arch, '', 'arch is off by default';  
  };
  
  $ENV{ALIEN_ARCH} = 1;
  
  subtest 'env override' => sub {
    plan tests => 1;
    my $builder = Alien::Builder->new;
    is !!$builder->alien_prop_arch, 1, 'arch is on by default';  
  };

  subtest override => sub {
    plan tests => 1;
    my $builder = Alien::Builder->new( arch => 1 );
    is !!$builder->alien_prop_arch, 1, 'arch is on';
  };

};

subtest ffi_name => sub {
  plan tests => 3;

  subtest default => sub {
    plan tests => 1;
    my $builder = Alien::Builder->new;
    is $builder->alien_prop_ffi_name, '', 'default is ""';
  };
  
  subtest 'defer to pkg_config name' => sub {
    plan tests => 1;
    my $builder = Alien::Builder->new(
      name => 'foobar',
    );
    is $builder->alien_prop_ffi_name, 'foobar', 'default to alien_prop_name';
  };

  subtest 'override pkg_config name' => sub {
    plan tests => 1;
    my $builder = Alien::Builder->new(
      name => 'foobar',
      ffi_name => 'baz',
    );
    is $builder->alien_prop_ffi_name, 'baz', 'default to alien_prop_name';
  };

};

subtest inline_auto_include => sub {
  plan tests => 2;
  
  subtest default => sub {
    plan tests => 1;
    my $builder = Alien::Builder->new;
    is_deeply $builder->alien_prop_inline_auto_include, [], 'default is empty list';
  };

  subtest default => sub {
    plan tests => 1;
    my $builder = Alien::Builder->new( inline_auto_include => ['-I/foo', '-I/bar'] );
    is_deeply $builder->alien_prop_inline_auto_include, [qw( -I/foo -I/bar )], 'with values';
  };

};

subtest isolate_dynamic => sub {
  plan tests => 3;

  subtest default => sub {
    plan tests => 1;
    my $builder = Alien::Builder->new;
    is !!$builder->alien_prop_isolate_dynamic, 1, 'on by default';
  };

  subtest on => sub {
    plan tests => 1;
    my $builder = Alien::Builder->new( isolate_dynamic => 1 );
    is !!$builder->alien_prop_isolate_dynamic, 1, 'on';
  };

  subtest off => sub {
    plan tests => 1;
    my $builder = Alien::Builder->new( isolate_dynamic => 0 );
    is !!$builder->alien_prop_isolate_dynamic, '', 'off';
  };

};

subtest 'provides cflags libs' => sub {
  plan tests => 2;
  
  subtest default => sub {
    plan tests => 2;
    my $builder = Alien::Builder->new;
    is $builder->alien_prop_provides_cflags, undef, 'cflags undef';
    is $builder->alien_prop_provides_libs, undef, 'libs undef';
  };
  
  subtest 'with values' => sub {
    plan tests => 2;
    my $builder = Alien::Builder->new( provides_cflags => '-DFOO', provides_libs => '-lfoo' );
    is $builder->alien_prop_provides_cflags, '-DFOO', 'cflags undef';
    is $builder->alien_prop_provides_libs, '-lfoo', 'libs undef';
  };

};

subtest version_check => sub {
  plan tests => 2;
  
  subtest default => sub {
    plan tests => 1;
    my $builder = Alien::Builder->new;
    is $builder->alien_prop_version_check, '%{pkg_config} --modversion %n', 'has default value';
  };

  subtest 'with value' => sub {
    plan tests => 1;
    my $builder = Alien::Builder->new( version_check => 'foo --bar' );
    is $builder->alien_prop_version_check, 'foo --bar', 'override';
  };

};

subtest alien_do_system => sub {

  my $builder = Alien::Builder->new(
    env => { FOO => 'bar', BAZ => undef },
    helper => { foo => '"bar2"' },
  );
  
  my(undef, undef, %r) = capture { $builder->alien_do_system('%X', -e => 'print $ENV{FOO}') };
  is $r{stdout}, 'bar', 'stdout=bar';
  is !!$r{success}, 1, 'success=1';

  (undef, undef, %r) = capture { $builder->alien_do_system('%X', -e => 'print $ARGV[0]', '%{foo}') };
  is $r{stdout}, 'bar2', 'stdout=bar2';
  is !!$r{success}, 1, 'success=1';

  SKIP: {
    # capturing STDERR on windows with Capture::Tiny seems to be somewhat broken.
    skip 'see https://github.com/dagolden/Capture-Tiny/issues/7', 2 if $^O eq 'MSWin32';
    (undef, undef, %r) = capture { $builder->alien_do_system('%X', -e => 'print STDERR "stuff"') };
    is $r{stderr}, 'stuff', 'stderr=stuff';
    is !!$r{success}, 1, 'success=1';
  };

  (undef, undef, %r) = capture { $builder->alien_do_system('%X', -e => 'exit 2') };
  is !!$r{success}, '', 'success=0';
};

subtest retrievor => sub {

  subtest default => sub {
    my $builder = Alien::Builder->new;
    isa_ok $builder->alien_prop_retrievor, 'Alien::Builder::Retrievor';
  };
  
  subtest 'alt class' => sub {
    my $builder = Alien::Builder->new( retrievor_class => 'My::Retrievor' );
    isa_ok $builder->alien_prop_retrievor, 'My::Retrievor';
  };

};

package
  My::Intr;

use base qw( Alien::Builder::Interpolator );

sub new
{
  my($class, %args) = @_;
  $class->SUPER::new(
    vars => { f => 'foo', b => 'bar' },
    helpers => $args{helpers},
  );
}

package
  Alien::Builder::Interpolator::Foo;

use base qw( Alien::Builder::Interpolator );

package
  Alien::Builder::Extractor::Plugin::Foo;

sub extract {}


package
  My::Retrievor;

use base qw( Alien::Builder::Retrievor );
