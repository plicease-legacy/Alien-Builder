use strict;
use warnings;

die if @ARGV;

open my $fh, '>', 'build.txt';
print $fh "build data";
close $fh;
