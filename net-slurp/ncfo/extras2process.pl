#!/usr/bin/perl
use warnings;
use strict;

for my $dir (@ARGV) {
  my @files = glob "$dir/*";
  s,.*/,, for @files;
  my $name = $dir;  $name =~ s,.*/,,;  $name =~ s,.*\.,,;
  print "$dir/$_=../$name/$_\n" for @files;
}
