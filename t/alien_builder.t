use strict;
use warnings;
use lib 'corpus/basic/lib';
use File::chdir;
use Alien::Builder;
use File::Temp qw( tempdir );
use Config;
use Test::More tests => 15;

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
    ok !!$builder->_msys, '_msys is on';

  };

  subtest off => sub {
    plan tests => 2;

    my $builder = Alien::Builder->new(
      build_commands => [ 'something', 'other', 'than', 'autoconf' ],
    );

    ok !$builder->_autoconf, '_autoconf is off';
    ok !$builder->_msys, '_msys is off';
  
  };
  
  subtest on => sub {
    plan tests => 2;
  
    subtest string => sub {
      plan tests => 2;
    
      my $builder = Alien::Builder->new(
        build_commands => [ 'something', '%c', 'here' ],
      );
    
      ok !!$builder->_autoconf, '_autoconf is on';
      ok !!$builder->_msys, '_msys is on';
    };
    
    subtest list => sub {
      plan tests => 2;

      my $builder = Alien::Builder->new(
        build_commands => [ [ 'something', '%c', 'here' ] ],
      );
    
      ok !!$builder->_autoconf, '_autoconf is on';
      ok !!$builder->_msys, '_msys is on';
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
    ok !!$builder->_msys, '_msys is on';
    
  
  };

  subtest off => sub {
    plan tests => 2;
    
    my $builder = Alien::Builder->new(
      build_commands => [ 'something', 'other', 'than', 'autoconf' ],
      msys => 0,
    );

    ok !$builder->_autoconf, '_autoconf is off';
    ok !$builder->_msys, '_msys is off';
    
  
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
      is_deeply $builder->_bin_requires, {}, 'bin requires is empty';
    
    };
    
    subtest 'some values' => sub {
      plan tests => 1;

      my $builder = Alien::Builder->new(
        bin_requires => {
          'Alien::Foo' => 0,
          'Alien::Bar' => '1.234',
        },
      );
      is_deeply $builder->_bin_requires, {
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
      is_deeply $builder->_bin_requires, { 'Alien::MSYS' => 0 }, 'bin requires has Alien::MSYS';
    
    };

    subtest 'some values' => sub {
      plan tests => 1;

      my $builder = Alien::Builder->new(
        bin_requires => {
          'Alien::Foo' => 0,
          'Alien::Bar' => '1.234',
        },
      );
      is_deeply $builder->_bin_requires, {
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
      is_deeply $builder->_bin_requires, {
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
  plan tests => 2;

  my $intr = Alien::Builder->new->_interpolator;
  
  isa_ok $intr, 'Alien::Builder::Interpolator::Default';
  isa_ok $intr, 'Alien::Builder::Interpolator';

};

subtest 'env' => sub {
  plan tests => 4;

  subtest default => sub {
    local $Alien::Builder::OS = 'linux';
  
    my $builder = Alien::Builder->new;

    my %env = %{ $builder->_env };
    
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
    
    is_deeply $builder->_env, {}, 'empty env';
  
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
        my %path = map { $_ => 1 } split $Config{path_sep}, $builder->_env->{PATH};
        ok $_, "$_ is in PATH" for @$test;
      };
    }
    
    # TODO: support Alien::CMake
    # probably by just adding bin_dir interface
    
    subtest 'Alien::Bogus' => sub {
    
      plan tests => 1;
      
      my $builder = Alien::Builder->new( bin_requires => { 'Alien::Bogus' => 0 } );
      
      eval { $builder->_env };
      like $@, qr{Bogus\.pm}, 'dies with message';
    
    };
    
    subtest 'Alien::Foo 0.05' => sub {
      plan tests => 1;

      my $builder = Alien::Builder->new( bin_requires => { 'Alien::Foo' => '0.05' } );
      
      eval { $builder->_env };
      is $@, '', 'no crash';
      note $@ if $@;
    };

    subtest 'Alien::Foo 1.05' => sub {
      plan tests => 1;

      my $builder = Alien::Builder->new( bin_requires => { 'Alien::Foo' => '1.05' } );
      
      eval { $builder->_env };
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
    
    is $builder->_env->{FOO}, 'foo', 'FOO=foo';
    is $builder->_env->{BAR}, undef, 'BAR=undef';
  
  };

};

subtest name => sub {
  plan tests => 2;

  subtest default => sub {
    plan tests => 1;
  
    my $builder = Alien::Builder->new;
    
    is $builder->_interpolator->interpolate('%n'), '', '%n is empty string';
  
  };
  
  subtest 'with value' => sub {
    plan tests => 1;

    my $builder = Alien::Builder->new( name => 'foo' );
    
    is $builder->_interpolator->interpolate('%n'), 'foo', '%n is foo'

  };

};

subtest '%c' => sub {

  subtest default => sub {
  
    subtest 'unix like' => sub {
      local $Alien::Builder::OS = 'linux';
      my $builder = Alien::Builder->new;  
      is $builder->_interpolator->interpolate('%c'), './configure --with-pic', 'is ./configure --with-pic';
    };
    
    subtest 'windows' => sub {
      local $Alien::Builder::OS = 'MSWin32';
      my $builder = Alien::Builder->new;  
      is $builder->_interpolator->interpolate('%c'), 'sh configure --with-pic', 'is sh configure --with-pic';
    };
  
  };


};

subtest helper => sub {
  plan tests => 1;

  my $builder = Alien::Builder->new(
    helper => { foo => '"abc" . "def"' },
  );
  
  my $string = $builder->_interpolator->interpolate('%{foo}');
  is $string, 'abcdef', 'used heler';

};

subtest build_commands => sub {
  plan tests => 2;
  my $builder = Alien::Builder->new;
  isa_ok $builder->_build_commands, 'Alien::Builder::CommandList';
  is_deeply [$builder->_build_commands->raw], [['%c --prefix=%s'],['make']];
};

subtest install_commands => sub {
  plan tests => 2;
  my $builder = Alien::Builder->new;
  isa_ok $builder->_install_commands, 'Alien::Builder::CommandList';
  is_deeply [$builder->_install_commands->raw], [['make install']];
};

subtest test_commands => sub {
  my $builder = Alien::Builder->new;
  isa_ok $builder->_test_commands, 'Alien::Builder::CommandList';
  is_deeply [$builder->_test_commands->raw], [];
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
