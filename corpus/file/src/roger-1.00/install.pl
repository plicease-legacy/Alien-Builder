use strict;
use warnings;

die if @ARGV;

open my $fh, '>', 'install.txt';
print $fh "install data";
close $fh;
