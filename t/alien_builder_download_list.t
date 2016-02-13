use strict;
use warnings;
use Test::More tests => 2;
use URI;
use Alien::Builder::Download::List;

subtest default => sub {

  my $list = Alien::Builder::Download::List->new;
  
  isa_ok $list, 'Alien::Builder::Download::List';

  is_deeply [$list->list], [], 'empty list';
  is $list->uri_for('anything'), undef, 'uri_for returns undef';

};

subtest 'with values' => sub {

  my $list = Alien::Builder::Download::List->new(
    map { ("$_.tar.gz" => URI->new("http://example.com/downloads/$_")) } qw( foo-1.00 foo-1.02 bar-1.00 )
  );

  is_deeply [$list->list], [qw( bar-1.00.tar.gz foo-1.00.tar.gz foo-1.02.tar.gz )], 'full list';
  isa_ok $list->uri_for('bar-1.00.tar.gz'), 'URI';

};
