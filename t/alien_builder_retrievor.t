use strict;
use warnings;
use Test::More tests => 1;
use Alien::Builder::Retrievor;

subtest basic => sub {
  plan tests => 1;

  my $r = Alien::Builder::Retrievor->new;
  isa_ok $r, 'Alien::Builder::Retrievor';

};
