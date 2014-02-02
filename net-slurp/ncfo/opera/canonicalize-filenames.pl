#!/usr/bin/perl
use warnings;
use strict;

use Cwd qw( getcwd );
use File::Spec qw( splitpath catpath splitdir );

# ----------------------------------------------------------------------

my $short_name = (split(m!/!, getcwd))[-2];
$short_name =~ s/[^A-Z0-9]+//g;

# ----------------------------------------------------------------------

sub canonicalize_file ( $ ) {
  my ($file) = @_;
  $file =~ s/\.mp3$//i;
  $file =~ s/^[^\.]*?(?=\d)/${short_name}/
    or $file =~ s/practice//i;
  $file =~ s/^(\Q${short_name}\E\d+)[-_](\d+)/$1.$2/;
  #$file =~ s/(\d+)/sprintf "%02d", $1/ge;
  $file . '.mp3';
}

sub canonicalize ( $ ) {
  my ($path) = @_;
  my (@path) = split m!/+!, $path;
  $path[-1] = canonicalize_file $path[-1];
  join '/', @path;
}

# ----------------------------------------------------------------------

my @output;
while (<>) {
  chomp;
  my ($in, $out) = split /=/, $_, 2;
  defined $out or die "bad input format: '$_'";

  my $fixed = canonicalize $out;
  print "$in=$fixed\n";
}
