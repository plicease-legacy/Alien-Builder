use strict;
use warnings;
use Test::More tests => 4;
use Alien::Builder::Retriever;
use URI;
use URI::file;

subtest basic => sub {
  plan tests => 1;

  my $r = Alien::Builder::Retriever->new;
  isa_ok $r, 'Alien::Builder::Retriever';

};

my $corpus = URI::file->new_abs('corpus/');
# corpus/file/repo/

subtest 'fetch all' => sub {

  my $uri = URI->new_abs('file/repo', $corpus);
  note "uri = $uri";
  
  my $r = Alien::Builder::Retriever->new(
    $uri
  );
  
  isa_ok $r, 'Alien::Builder::Retriever';
  
  my $dl = $r->retrieve;
  
  isa_ok $dl, 'Alien::Builder::Download::File';

  is $dl->_filename, 'hello-1.02.tar.gz';
  is_deeply [map { $_->name } $r->_candidates], [qw( bar-1.00.tar.gz foo-1.00.tar.gz hello-1.00.tar.gz hello-1.02.tar.gz  )];
  isa_ok(($r->_candidates)[0], 'Alien::Builder::Retriever::Candidate');

};

subtest 'candidate_class' => sub {
  
  my $uri = URI->new_abs('file/repo', $corpus);
  note "uri = $uri";
  
  my $r = Alien::Builder::Retriever->new(
    $uri => { candidate_class => 'My::Candidate' },
  );
  
  $r->retrieve;
  
  isa_ok(($r->_candidates)[0], 'My::Candidate');
  
};

subtest 'pattern' => sub {

  my $uri = URI->new_abs('file/repo', $corpus);
  note "uri = $uri";
  
  my $r = Alien::Builder::Retriever->new(
    $uri => { pattern => '^hello-(([0-9]+\.)*[0-9]+)\.tar\.gz$' },
  );
  
  my $dl = $r->retrieve;
  isa_ok $dl, 'Alien::Builder::Download::File';

  is $dl->_filename, 'hello-1.02.tar.gz';
  is_deeply [map { $_->name } $r->_candidates], [qw( hello-1.00.tar.gz hello-1.02.tar.gz  )];
  isa_ok(($r->_candidates)[0], 'Alien::Builder::Retriever::Candidate');

};

package
  My::Candidate;

use base qw( Alien::Builder::Retriever::Candidate );
