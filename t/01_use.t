use strict;
use warnings;
use Test::More tests => 14;

use_ok 'Alien::Builder';
use_ok 'Alien::Builder::CommandList';
use_ok 'Alien::Builder::Download';
use_ok 'Alien::Builder::Download::File';
use_ok 'Alien::Builder::Download::List';
use_ok 'Alien::Builder::Download::Plugin::HTTPTiny';
use_ok 'Alien::Builder::Download::Plugin::Local';
use_ok 'Alien::Builder::Download::Plugin::NetFTP';
use_ok 'Alien::Builder::EnvLog';
use_ok 'Alien::Builder::Extractor::Plugin::ArchiveTar';
use_ok 'Alien::Builder::Interpolator';
use_ok 'Alien::Builder::Interpolator::Classic';
use_ok 'Alien::Builder::Retriever';
use_ok 'Alien::Builder::Retriever::Candidate';
