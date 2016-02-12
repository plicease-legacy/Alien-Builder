use strict;
use warnings;
use Test::More tests => 3;
use Alien::Builder::CommandList;

subtest simple => sub {

  plan tests => 1;

  my $builder = eval { Alien::Builder::CommandList->new };
  diag $@ if $@;
  isa_ok $builder, 'Alien::Builder::CommandList';

};

subtest interpolate => sub {

  plan tests => 3;

  my $builder = Alien::Builder::CommandList->new(
    [
      '%f is %b',
      [ '%f', 'is', '%b' ],
    ],
    interpolator => Alien::Builder::Interpolator->new(
      vars => { f => 'foo', b => 'bar' },
    )
  );
  
  isa_ok $builder, 'Alien::Builder::CommandList';
  
  my @commands = $builder->interpolate;

  is_deeply $commands[0], ["foo is bar"], "string interpolation";  
  is_deeply $commands[1], ['foo', 'is', 'bar'], 'list interpolation';
};

subtest execute => sub {

  plan tests => 3;

  my @actual;
  
  my $builder = Alien::Builder::CommandList->new(
    [
      'foo is bar',
      [ 'foo', 'is', 'bar' ],
    ],
    system => sub {
      push @actual, \@_;
    },
  );

  isa_ok $builder, 'Alien::Builder::CommandList';
  
  $builder->execute;

  is_deeply $actual[0], ["foo is bar"], "string execute";  
  is_deeply $actual[1], ['foo', 'is', 'bar'], 'list execute';

};
