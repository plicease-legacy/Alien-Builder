use strict;
use warnings;
use Test::More tests => 2;
use Alien::Builder::Interpolator::Classic;

subtest 'x and X' => sub {
  plan tests => 3;

  my $intr = Alien::Builder::Interpolator::Classic->new;

  my $lower = $intr->interpolate('%x');
  my $upper = $intr->interpolate('%X');
  
  isnt $lower, '', "is something: $lower";
  isnt $upper, '', "is something: $upper";

  unlike $upper, qr{\\}, '%x does not have backslash';

};

subtest '%p' => sub {
  plan tests => 2;
  
  subtest 'unix like' => sub {
    plan tests => 1;
    local $Alien::Builder::OS = 'linux';
    
    my $intr = Alien::Builder::Interpolator::Classic->new;
    is $intr->interpolate('%pconfigure'), './configure', 'is ./configure';

  };
  
  subtest 'windows' => sub {
    plan tests => 1;
    local $Alien::Builder::OS = 'MSWin32';

    my $intr = Alien::Builder::Interpolator::Classic->new;
    is $intr->interpolate('%pconfigure'), 'configure', 'is configure';
  };

};
