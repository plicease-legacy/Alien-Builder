use strict;
use warnings;
use Test::More;
use Alien::Builder::Interpolator;

subtest 'create simple' => sub {
  my $itr = Alien::Builder::Interpolator->new;
  isa_ok $itr, 'Alien::Builder::Interpolator';  
  is $itr->interpolate("%%"), '%', 'double %';
  is $itr->interpolate("%%%%"), '%%', 'double double %';
};

subtest 'var' => sub {

  my $itr = Alien::Builder::Interpolator->new(
    vars => { a => "abc", p => "%a" },
  );
  
  is $itr->vars->{a}, 'abc', 'accessor';
  is $itr->vars->{p}, '%a',  'accessor 2';
  
  is $itr->interpolate("hi %a there"), "hi abc there", "simple interpolate";
  is $itr->interpolate("hi %a %% %a there"), 'hi abc % abc there', "multiple interpolate";
  is $itr->interpolate("hi %a %p %a there"), 'hi abc %a abc there', "var with % as value";

};

subtest 'helper' => sub {

  my $itr = Alien::Builder::Interpolator->new(
    vars    => { a => "abc" },
    helpers => { ab => '"ab" . "bc"', p2 => '"%{ab}"', p3 => "'%a'" },
  );

  is $itr->helpers->{p2}, '"%{ab}"', 'accessor';
  
  is $itr->interpolate("hi %{ab} there"), "hi abbc there", 'simple helper';
  is $itr->interpolate("hi %{ab} %{p2} there"), "hi abbc %{ab} there", "helper with %{}";
  is $itr->interpolate("hi %{ab} %{p3} %a there"), "hi abbc %a abc there", 'helper with %.';

  is $itr->execute_helper('ab'), 'abbc', 'execute_helper';

};

subtest undef => sub {
  
  my $itr = Alien::Builder::Interpolator->new;
  
  is $itr->interpolate(undef), undef, 'undef => undef';

};

done_testing;
