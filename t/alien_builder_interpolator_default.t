use strict;
use warnings;
use Test::More tests => 1;
use Alien::Builder::Interpolator::Default;

subtest 'x and X' => sub {
  plan tests => 3;

  my $intr = Alien::Builder::Interpolator::Default->new;

  my $lower = $intr->interpolate('%x');
  my $upper = $intr->interpolate('%X');
  
  isnt $lower, '', "is something: $lower";
  isnt $upper, '', "is something: $upper";

  unlike $upper, qr{\\}, '%x does not have backslash';

};

