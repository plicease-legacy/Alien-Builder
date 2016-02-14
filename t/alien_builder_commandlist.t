use strict;
use warnings;
use Test::More tests => 3;
use Alien::Builder::CommandList;

subtest simple => sub {

  plan tests => 1;

  my $cl = eval { Alien::Builder::CommandList->new };
  diag $@ if $@;
  isa_ok $cl, 'Alien::Builder::CommandList';

};

subtest 'interpolate and raw'=> sub {

  plan tests => 5;

  my $cl = Alien::Builder::CommandList->new(
    [
      '%f is %b',
      [ '%f', 'is', '%b' ],
    ],
    interpolator => Alien::Builder::Interpolator->new(
      vars => { f => 'foo', b => 'bar' },
    )
  );
  
  isa_ok $cl, 'Alien::Builder::CommandList';
  
  my @commands = $cl->interpolate;

  is_deeply $commands[0], ["foo is bar"], "string interpolation";  
  is_deeply $commands[1], ['foo', 'is', 'bar'], 'list interpolation';
  
  @commands = $cl->raw;
  
  is_deeply $commands[0], ['%f is %b'], 'string raw';
  is_deeply $commands[1], ['%f', 'is', '%b'], 'list raw';
};

subtest execute => sub {

  plan tests => 3;

  my @actual;
  
  my $cl = Alien::Builder::CommandList->new(
    [
      'foo is bar',
      [ 'foo', 'is', 'bar' ],
    ],
    system => sub {
      push @actual, \@_;
    },
  );

  isa_ok $cl, 'Alien::Builder::CommandList';
  
  $cl->execute;

  is_deeply $actual[0], ["foo is bar"], "string execute";  
  is_deeply $actual[1], ['foo', 'is', 'bar'], 'list execute';

};
