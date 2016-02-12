use strict;
use warnings;
use Alien::Builder;
use Test::More tests => 1;

subtest 'simple' => sub {

  my $builder = eval { Alien::Builder->new };
  isa_ok $builder, 'Alien::Builder';

};
