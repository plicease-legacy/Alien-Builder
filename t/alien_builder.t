use strict;
use warnings;
use lib 'corpus/basic/lib';
use File::chdir;
use Alien::Builder;
use File::Temp qw( tempdir );
use Config;
use Test::More;
use Capture::Tiny qw( capture capture_merged );
use URI::file;

$Alien::Builder::BUILD_DIR = tempdir( CLEANUP => 1 );

subtest 'simple' => sub {
  my $builder = eval { Alien::Builder->new };
  isa_ok $builder, 'Alien::Builder';

};

subtest 'autoconf' => sub {
  subtest default => sub {
    my $builder = Alien::Builder->new;
    ok !!$builder->_autoconf, '_autoconf is on';
    ok !!$builder->msys, '_msys is on';

  };

  subtest off => sub {
    my $builder = Alien::Builder->new(
      build_commands => [ 'something', 'other', 'than', 'autoconf' ],
    );

    ok !$builder->_autoconf, '_autoconf is off';
    ok !$builder->msys, '_msys is off';
  
  };
  
  subtest on => sub {
    subtest string => sub {
      my $builder = Alien::Builder->new(
        build_commands => [ 'something', '%c', 'here' ],
      );
    
      ok !!$builder->_autoconf, '_autoconf is on';
      ok !!$builder->msys, '_msys is on';
    };
    
    subtest list => sub {
      my $builder = Alien::Builder->new(
        build_commands => [ [ 'something', '%c', 'here' ] ],
      );
    
      ok !!$builder->_autoconf, '_autoconf is on';
      ok !!$builder->msys, '_msys is on';
    };
  
  };

};

subtest msys => sub {
  subtest on => sub {
    my $builder = Alien::Builder->new(
      build_commands => [ 'something', 'other', 'than', 'autoconf' ],
      msys => 1,
    );

    ok !$builder->_autoconf, '_autoconf is off';
    ok !!$builder->msys, '_msys is on';
    
  
  };

  subtest off => sub {
    my $builder = Alien::Builder->new(
      build_commands => [ 'something', 'other', 'than', 'autoconf' ],
      msys => 0,
    );

    ok !$builder->_autoconf, '_autoconf is off';
    ok !$builder->msys, '_msys is off';
    
  
  };

};

subtest bin_requires => sub {
  subtest 'unix like' => sub {
    local $Alien::Builder::OS = 'linux';
    
    subtest default => sub {
      my $builder = Alien::Builder->new;
      is_deeply $builder->bin_requires, {}, 'bin requires is empty';
    
    };
    
    subtest 'some values' => sub {
      my $builder = Alien::Builder->new(
        bin_requires => {
          'Alien::Foo' => 0,
          'Alien::Bar' => '1.234',
        },
      );
      is_deeply $builder->bin_requires, {
        'Alien::Foo' => 0,
        'Alien::Bar' => '1.234',
      }, 'matches';
      is $builder->alien_build_requires->{'Alien::Foo'}, 0;
      is $builder->alien_build_requires->{'Alien::Bar'}, '1.234';

    };
  };
  
  subtest 'windows' => sub {
    local $Alien::Builder::OS = 'MSWin32';

    subtest default => sub {
    
      my $builder = Alien::Builder->new;
      is_deeply $builder->bin_requires, { 'Alien::MSYS' => 0 }, 'bin requires has Alien::MSYS';
      is $builder->alien_build_requires->{'Alien::MSYS'}, 0;
    
    };

    subtest 'some values' => sub {

      my $builder = Alien::Builder->new(
        bin_requires => {
          'Alien::Foo' => 0,
          'Alien::Bar' => '1.234',
        },
      );
      is_deeply $builder->bin_requires, {
        'Alien::Foo' => 0,
        'Alien::Bar' => '1.234',
        'Alien::MSYS' => 0,
      }, 'matches';

      is $builder->alien_build_requires->{'Alien::Foo'}, 0;
      is $builder->alien_build_requires->{'Alien::Bar'}, '1.234';
      is $builder->alien_build_requires->{'Alien::MSYS'}, 0;

    };

    subtest 'some values sans MSYS' => sub {

      my $builder = Alien::Builder->new(
        build_commands => [],
        bin_requires => {
          'Alien::Foo' => 0,
          'Alien::Bar' => '1.234',
        },
      );
      is_deeply $builder->bin_requires, {
        'Alien::Foo' => 0,
        'Alien::Bar' => '1.234',
      }, 'matches';

      is $builder->alien_build_requires->{'Alien::Foo'}, 0;
      is $builder->alien_build_requires->{'Alien::Bar'}, '1.234';
      is $builder->alien_build_requires->{'Alien::MSYS'}, undef;

    };
  };

};

subtest env_log => sub {

  subtest default => sub {

    my $builder = Alien::Builder->new;
    isa_ok $builder->_env_log, 'Alien::Builder::EnvLog';

  };

};

subtest 'cat file and dir' => sub {

  my $root = tempdir( CLEANUP => 1 );

  unlike Alien::Builder::_catfile( $root, qw( foo bar baz ) ), qr{\\}, 'no \\ in file';
  unlike Alien::Builder::_catdir( $root, qw( foo bar baz ) ), qr{\\}, 'no \\ in dir';

};

subtest 'filter_defines' => sub {
  
  is Alien::Builder::_filter_defines("-I/foo -DFOO=1 -L/bar   -lbaz"), '-I/foo -L/bar -lbaz', 'filters out define';

};

subtest 'interpolator' => sub {

  subtest default => sub {
    my $intr = Alien::Builder->new->interpolator;
    isa_ok $intr, 'Alien::Builder::Interpolator::Default';
    isa_ok $intr, 'Alien::Builder::Interpolator';
  };
  
  subtest 'fully qualified' => sub {
    my $intr = Alien::Builder->new(
      interpolator => 'Alien::Builder::Interpolator::Foo',
    )->interpolator;
    isa_ok $intr, 'Alien::Builder::Interpolator::Foo';
  };

  subtest 'abbreviated' => sub {
    my $intr = Alien::Builder->new(
      interpolator => 'Foo',
    )->interpolator;
    isa_ok $intr, 'Alien::Builder::Interpolator::Foo';
  };

};

subtest 'extractor' => sub {

  subtest default => sub {
    my $xtor = Alien::Builder->new->extractor;
    is $xtor, 'Alien::Builder::Extractor::Plugin::ArchiveTar';
    ok $xtor->can('extract'), 'can extract';
  };

  subtest 'fully qualified' => sub {
    my $xtor = Alien::Builder->new( extractor => 'Alien::Builder::Extractor::Plugin::Foo' )->extractor;
    is $xtor, 'Alien::Builder::Extractor::Plugin::Foo';
    ok $xtor->can('extract'), 'can extract';
  };

  subtest 'abbreviated' => sub {
    my $xtor = Alien::Builder->new( extractor => 'Foo' )->extractor;
    is $xtor, 'Alien::Builder::Extractor::Plugin::Foo';
    ok $xtor->can('extract'), 'can extract';
  };
  
};

subtest 'env' => sub {

  subtest default => sub {
    local $Alien::Builder::OS = 'linux';
  
    my $builder = Alien::Builder->new;

    my %env = %{ $builder->env };
    
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
    
    is_deeply $builder->env, {}, 'empty env';
  
  };
  
  subtest bin_requires => sub {
  
    my @tests = (
      [ 'MSYS' => '/some/msys/path/bin' ],
      [ 'Autotools' => '/some/ac/path/bin', '/some/am/path/bin', '/some/lt/path/bin' ],
      [ 'Bar' => '/some/bar/path/bin' ],
      [ 'Foo' => '/some/foo/path/bin' ],
      [ 'TinyCC' => '/some/tcc/path/bin' ],
    );
    
    foreach my $test (@tests)
    {
      my $name = 'Alien::' . shift @$test;
      subtest $name => sub {
        my $builder = Alien::Builder->new(
          bin_requires => {
            $name => 0
          },
        );
        my %path = map { $_ => 1 } split $Config{path_sep}, $builder->env->{PATH};
        ok $_, "$_ is in PATH" for @$test;
      };
    }
    
    subtest 'Alien::Bogus' => sub {
    
      my $builder = Alien::Builder->new( bin_requires => { 'Alien::Bogus' => 0 } );
      
      eval { $builder->env };
      like $@, qr{Bogus\.pm}, 'dies with message';
    
    };
    
    subtest 'Alien::Foo 0.05' => sub {
      my $builder = Alien::Builder->new( bin_requires => { 'Alien::Foo' => '0.05' } );
      
      eval { $builder->env };
      is $@, '', 'no crash';
      note $@ if $@;
    };

    subtest 'Alien::Foo 1.05' => sub {
      my $builder = Alien::Builder->new( bin_requires => { 'Alien::Foo' => '1.05' } );
      
      eval { $builder->env };
      like $@, qr{Alien::Foo}, 'dies with message';
    };
    
  };
  
  subtest overrides => sub {
    my $builder = Alien::Builder->new(
      interpolator => 'My::Intr',
      env => {
        FOO => '%f',
        BAR => undef,
      },
      version_check => 'false',
    );
    
    is $builder->env->{FOO}, 'foo', 'FOO=foo';
    is $builder->env->{BAR}, undef, 'BAR=undef';
  
  };

};

subtest name => sub {
  subtest default => sub {
    my $builder = Alien::Builder->new;
    
    is $builder->interpolator->interpolate('%n'), '', '%n is empty string';
  
  };
  
  subtest 'with value' => sub {
    my $builder = Alien::Builder->new( name => 'foo' );
    
    is $builder->interpolator->interpolate('%n'), 'foo', '%n is foo'

  };

};

subtest '%c' => sub {

  subtest default => sub {
  
    subtest 'unix like' => sub {
      local $Alien::Builder::OS = 'linux';
      my $builder = Alien::Builder->new;  
      is $builder->interpolator->interpolate('%c'), './configure --with-pic', 'is ./configure --with-pic';
    };
    
    subtest 'windows' => sub {
      local $Alien::Builder::OS = 'MSWin32';
      my $builder = Alien::Builder->new;  
      is $builder->interpolator->interpolate('%c'), 'sh configure --with-pic', 'is sh configure --with-pic';
    };
  
  };


};

subtest helper => sub {
  my $builder = Alien::Builder->new(
    helper => { foo => '"abc" . "def"' },
  );
  
  my $string = $builder->interpolator->interpolate('%{foo}');
  is $string, 'abcdef', 'used heler';

  my $pkg_config = $builder->interpolator->interpolate('%{pkg_config}');
  isnt $pkg_config, '', "pkg_config = $pkg_config"

};

subtest build_commands => sub {
  my $builder = Alien::Builder->new;
  isa_ok $builder->build_commands, 'Alien::Builder::CommandList';
  is_deeply [$builder->build_commands->raw], [['%c --prefix=%s'],['make']];
};

subtest install_commands => sub {
  my $builder = Alien::Builder->new;
  isa_ok $builder->install_commands, 'Alien::Builder::CommandList';
  is_deeply [$builder->install_commands->raw], [['make install']];
};

subtest test_commands => sub {
  my $builder = Alien::Builder->new;
  isa_ok $builder->test_commands, 'Alien::Builder::CommandList';
  is_deeply [$builder->test_commands->raw], [];
};

subtest arch => sub {
  delete $ENV{ALIEN_ARCH};

  subtest default => sub {
    my $builder = Alien::Builder->new;
    is !!$builder->arch, '', 'arch is off by default';  
  };
  
  $ENV{ALIEN_ARCH} = 1;
  
  subtest 'env override' => sub {
    my $builder = Alien::Builder->new;
    is !!$builder->arch, 1, 'arch is on by default';  
  };

  subtest override => sub {
    my $builder = Alien::Builder->new( arch => 1 );
    is !!$builder->arch, 1, 'arch is on';
  };

};

subtest ffi_name => sub {
  subtest default => sub {
    my $builder = Alien::Builder->new;
    is $builder->ffi_name, '', 'default is ""';
  };
  
  subtest 'defer to pkg_config name' => sub {
    my $builder = Alien::Builder->new(
      name => 'foobar',
    );
    is $builder->ffi_name, 'foobar', 'default to name';
  };

  subtest 'defer to pkg_config name without lib' => sub {
    my $builder = Alien::Builder->new(
      name => 'libfoobar',
    );
    is $builder->ffi_name, 'foobar', 'default to name';
  };

  subtest 'defer to pkg_config name without trailing version' => sub {
    my $builder = Alien::Builder->new(
      name => 'foobar-2.0',
    );
    is $builder->ffi_name, 'foobar', 'default to name';
  };

  subtest 'override pkg_config name' => sub {
    my $builder = Alien::Builder->new(
      name => 'foobar',
      ffi_name => 'baz',
    );
    is $builder->ffi_name, 'baz', 'default to name';
  };
  
};

subtest inline_auto_include => sub {
  subtest default => sub {
    my $builder = Alien::Builder->new;
    is_deeply $builder->inline_auto_include, [], 'default is empty list';
    is_deeply $builder->{config}->{inline_auto_include}, [], 'config matches';
  };

  subtest default => sub {
    my $builder = Alien::Builder->new( inline_auto_include => ['-I/foo', '-I/bar'] );
    is_deeply $builder->inline_auto_include, [qw( -I/foo -I/bar )], 'with values';
    is_deeply $builder->{config}->{inline_auto_include}, [qw( -I/foo -I/bar )], 'config matches';
  };

};

subtest isolate_dynamic => sub {
  subtest default => sub {
    my $builder = Alien::Builder->new;
    is !!$builder->isolate_dynamic, 1, 'on by default';
  };

  subtest on => sub {
    my $builder = Alien::Builder->new( isolate_dynamic => 1 );
    is !!$builder->isolate_dynamic, 1, 'on';
  };

  subtest off => sub {
    my $builder = Alien::Builder->new( isolate_dynamic => 0 );
    is !!$builder->isolate_dynamic, '', 'off';
  };

};

subtest 'provides cflags libs' => sub {
  subtest default => sub {
    my $builder = Alien::Builder->new;
    is $builder->provides_cflags, undef, 'cflags undef';
    is $builder->provides_libs, undef, 'libs undef';
    is $builder->{config}->{system_provides}->{Cflags}, undef;
    is $builder->{config}->{system_provides}->{Libs}, undef;
  };
  
  subtest 'with values' => sub {
    my $builder = Alien::Builder->new( provides_cflags => '-DFOO', provides_libs => '-lfoo' );
    is $builder->provides_cflags, '-DFOO', 'cflags undef';
    is $builder->provides_libs, '-lfoo', 'libs undef';
    is $builder->{config}->{system_provides}->{Cflags}, '-DFOO';
    is $builder->{config}->{system_provides}->{Libs}, '-lfoo';
  };

};

subtest version_check => sub {
  subtest default => sub {
    my $builder = Alien::Builder->new;
    is $builder->version_check, '%{pkg_config} --modversion %n', 'has default value';
  };

  subtest 'with value' => sub {
    my $builder = Alien::Builder->new( version_check => 'foo --bar' );
    is $builder->version_check, 'foo --bar', 'override';
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

subtest retriever => sub {

  subtest default => sub {
    my $builder = Alien::Builder->new;
    isa_ok $builder->retriever, 'Alien::Builder::Retriever';
  };
  
  subtest 'alt class' => sub {
    my $builder = Alien::Builder->new( retriever => 'My::Retriever' );
    isa_ok $builder->retriever, 'My::Retriever';
  };

};

subtest 'save/restore' => sub {

  my $state_file = File::Spec->catfile( tempdir( CLEANUP => 1 ), 'alien_builder.json' );

  subtest save => sub {
    my $builder = Alien::Builder->new;
    $builder->save($state_file);
    ok -f $state_file, "created: $state_file";
  };

  subtest restore=> sub {
    my $builder = Alien::Builder->restore($state_file);
    isa_ok $builder, 'Alien::Builder';
  };

};

subtest actions => sub {

  my $state_file = File::Spec->catfile( tempdir( CLEANUP => 1 ), 'alien_builder.json' );
  my $build_dir  = File::Spec->catdir( tempdir( CLEANUP => 1 ), '_alien' );
  my $prefix_dir = File::Spec->catdir( tempdir( CLEANUP => 1 ), 'local' );

  my $dump_state = q{
    use YAML::XS qw( Dump );
    use JSON::PP qw( decode_json );
    open my $fh, '<', $state_file;
    note Dump(decode_json(do { local $/; <$fh> }));
    close $fh;
  };
  
  subtest 'configure' => sub {
  
    my $builder = Alien::Builder->new(
      name => 'roger',
      build_dir => $build_dir,
      retriever_start => URI::file->new_abs('./corpus/file/repo2/')->as_string,
      build_commands => [ [ '%X', 'build.pl' ] ],
      test_commands => [ [ '%X', 'test.pl' ] ],
      install_commands => [ [ '%X', 'install.pl', '%s' ] ],
      prefix => $prefix_dir,
    );
    
    $builder->save($state_file);

    ok -f $state_file, "created: $state_file";
  };

  subtest 'download' => sub {
  
    my $builder = Alien::Builder->restore($state_file);
    $builder->action_download;
    
    my $filename = File::Spec->catfile($build_dir, 'roger-1.00.tar.gz');
    ok -f $filename, "copied tarball: $filename";

    $builder->save($state_file);
  };

  subtest 'extract' => sub {

    my $builder = Alien::Builder->restore($state_file);
    $builder->action_extract;
    
    my $dir = File::Spec->catfile($build_dir, 'roger-1.00');
    ok -d $dir, "extracted tarball $dir";

    $builder->save($state_file);
  };
  
  foreach my $stage (qw( build test install ))
  {
  
    subtest $stage => sub {
      my $method = "action_$stage";
    
      my $builder = Alien::Builder->restore($state_file);
      my($out, $err) = capture_merged { eval { $builder->$method }; $@ };
      note $out;
    
      $builder->save($state_file);
      is $err, '', 'did not throw exception';
      
      my $filename = File::Spec->catfile($build_dir, 'roger-1.00', "$stage.txt");
      ok -f $filename, "created $filename";
    };
  
  }
  
  subtest 'load_pkgconfig' => sub {
  
    my $builder = Alien::Builder->restore($state_file);
    my $pkgconfig = $builder->{config}->{pkgconfig}->{roger};
    isa_ok $pkgconfig, 'Alien::Base::PkgConfig';
    
    is $pkgconfig->keyword('Cflags'), '-I/opt/roger/include';
    is $pkgconfig->keyword('Libs'), '-L/opt/roger/lib -lroger';
  
  };
  
  subtest 'isolate dynamic' => sub {

    my $libroger_so = File::Spec->catfile($prefix_dir, 'dynamic', 'libroger.so');
    my $libroger_a  = File::Spec->catfile($prefix_dir, 'lib',     'libroger.a');
    
    ok -f $libroger_so, "so = $libroger_so";
    ok -f $libroger_a,  "a  = $libroger_a";

    note `ls -lR $prefix_dir`;
  
  };

  subtest 'fake' => sub {
  
    my $builder = Alien::Builder->restore($state_file);
    my($out, $err) = capture_merged { eval { $builder->action_fake }; $@ };
    note $out;
    
    is $err, '', 'did not throw exception';
  };

  #eval $dump_state;
};

subtest prefix => sub {

  subtest default => sub {
    my $builder = Alien::Builder->new;
    is $builder->interpolator->interpolate("%s"), '/usr/local';
  };
  
  subtest 'with value' => sub {
    my $builder = Alien::Builder->new( prefix => '/foo');
    is $builder->interpolator->interpolate("%s"), '/foo';
  };

};

subtest destdir => sub {

  local %ENV = %ENV;
  delete $ENV{DESTDIR};

  subtest default => sub {
    my $builder = Alien::Builder->new;
    is $builder->dest_dir, undef;
    is $builder->env->{DESTDIR}, undef;
    is $builder->alien_build_requires->{'File::Copy::Recursive'}, undef;
  };

  subtest default => sub {
    my $builder = Alien::Builder->new(dest_dir => 1);
    ok $builder->dest_dir, "dest_dir = @{[ $builder->dest_dir ]}";
    ok !-d $builder->dest_dir, 'does not exist YET';
    mkdir($builder->dest_dir);
    ok -d $builder->dest_dir, 'is creatable';
    is $builder->env->{DESTDIR}, $builder->dest_dir;
    is $builder->alien_build_requires->{'File::Copy::Recursive'}, 0;
  };

};

subtest 'HTML::Parser a build require on share install' => sub {

  local %ENV = %ENV;
  $ENV{ALIEN_INSTALL_TYPE} = 'share';
  
  my $builder = Alien::Builder->new;
  is $builder->alien_build_requires->{'HTML::Parser'}, 0;

};

done_testing;

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
  My::Retriever;

use base qw( Alien::Builder::Retriever );
