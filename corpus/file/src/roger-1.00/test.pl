use strict;
use warnings;

die if @ARGV;

open my $fh, '>', 'test.txt';
print $fh "test data";
close $fh;
