package Alien::Builder::Extractor::Plugin::ArchiveTar;

use strict;
use warnings;
use Archive::Tar;
use Carp qw( croak );
use File::Spec;
use File::chdir;

# ABSTRACT: Alien::Builder extractor for tarballs using Archive::Tar
# VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=head2 extract

=cut

sub extract
{
  my(undef, $download, $dir) = @_;
  
  my $tarball = $download->copy_to($dir);

  local $Archive::Tar::RESOLVE_SYMLINK = $Archive::Tar::RESOLVE_SYMLINK;
  $Archive::Tar::RESOLVE_SYMLINK = 'none' if $^O eq 'MSWin32';
  
  my $tar = Archive::Tar->new;
  $tar->read($tarball);

  my @roots = do {
    my %roots = map { s/\/.*$//; $_ => 1 } map { $_->full_path } $tar->get_files;
    sort keys %roots;
  };
  
  croak "no roots found in tarball" unless @roots > 0;
  if(@roots > 1)
  {
    my(undef,undef,$subdir) = File::Spec->splitpath($tarball);
    $subdir =~ s/\.tar(\.gz|\.bz2)?$//;
    $subdir =~ s/\.tgz$//;
    my $orig = $dir;
    $dir = File::Spec->catdir($orig, $subdir);
    my $i = 1;
    while(-e $dir)
    {
      $dir = File::Spec->catdir($orig, join('_', $subdir, $i++));
    }
    mkdir $dir;
  }

  local $CWD = $dir;  
  foreach my $file ($tar->get_files)
  {
    # ignore errors extracting symlinks on windows.
    # TODO: figure out a better way to handle this.
    # it is still rather noisy.
    my $ok = $file->is_symlink && $^O eq 'MSWin32'
      ? $file->extract || 1 : $file->extract;
    die "unable to extract @{[ $file->full_path ]}" unless $ok;
  }

  @roots == 1 ? File::Spec->catdir($dir, $roots[0]) : $dir;
}

1;
