use strict;
use warnings;
use Test::More tests => 2;
use Alien::Builder::Retrievor::Candidate;

subtest basic => sub {
  plan tests => 3;
  
  my $can = Alien::Builder::Retrievor::Candidate->new('foo.tar.gz' => 'http://www.foobar.com/downloads/foo.tar.gz');
  
  isa_ok $can, 'Alien::Builder::Retrievor::Candidate';
  is $can->name, 'foo.tar.gz';
  isa_ok $can->location, 'URI';
};

subtest 'location as hash' => sub {

  plan tests => 3;
  
  my $can = Alien::Builder::Retrievor::Candidate->new('foo.tar.gz' => { class => 'Foo', foo => 1, bar => 2 });
  
  isa_ok $can, 'Alien::Builder::Retrievor::Candidate';
  is $can->name, 'foo.tar.gz';
  isa_ok $can->location, 'HASH';

};
