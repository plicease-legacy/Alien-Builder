use strict;
use warnings;
use Alien::Builder::EnvLog;
use Test::More tests => 1;
use File::Spec;
use File::Temp qw( tempdir );
use Env qw( @PATH $FOO );

subtest simple => sub {

  plan tests => 8;

  my $log = Alien::Builder::EnvLog->new;
  
  isa_ok $log, 'Alien::Builder::EnvLog';

  eval { $log->prepend_path( PATH => '/foo/bar' ) };
  is $@, '', 'prepend_path';

  eval { $log->set( FOO => 'bar' ) };
  is $@, '', 'set';
  
  my $dir = tempdir( CLEANUP => 1 );
  
  eval { $log->write_log($dir) };
  is $@, '', 'write_log';

  my $config_pl = File::Spec->catfile($dir, 'env.pl');
  ok -r $config_pl, "exists: $config_pl";
  my $pl = do { open my $fh, '<', $config_pl; local $/; <$fh> };
  
  subtest 'perl populates values' => sub {
    plan tests => 3;
    local %ENV = %ENV;
    no warnings 'once';
    local *CORE::GLOBAL::system = sub {};
    eval $pl;
    is $@, '', 'generated perl compiles';
    diag $pl if $@;
    is $FOO, 'bar', 'FOO=bar';
    is $PATH[0], '/foo/bar', 'PATH[0] = /foo/bar';
  };

  subtest 'sh compiles' => sub {
    plan skip_all => 'Test requires non windows' if $^O eq 'MSWin32';
    plan skip_all => 'Test requires Shell::Config::Generate and Shell::Guess'
      unless $INC{'Shell/Config/Generate.pm'} && $INC{'Shell/Guess.pm'};
      
    my $config_sh = File::Spec->catfile($dir, 'env.sh');
    ok -r $config_sh, "exists: $config_sh";
    
    system 'sh', $config_sh;
    is $?, 0, 'sh compiles it okay';
  };

  subtest 'bat compiles' => sub {
    plan skip_all => 'Test requires windows' unless $^O eq 'MSWin32';
    plan skip_all => 'Test requires Shell::Config::Generate and Shell::Guess'
      unless $INC{'Shell/Config/Generate.pm'} && $INC{'Shell/Guess.pm'};
    
    my $config_bat = File::Spec->catfile($dir, 'env.bat');
    ok -r $config_bat, "exists: $config_bat";
    
    system $config_bat, 'force list mode';
    is $?, 0, 'bat syntax okay';
  };
  
};
