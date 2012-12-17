#!/usr/bin/perl
use warnings;
use strict;

# ----------------------------------------------------------------------

while (<>) {
  chomp;
  s,.*/,,;
  my $dir = $ARGV;  $dir =~ s,.*/,,;  $dir =~ s,\..*,,;
  print "mp3/$_=../$dir/$_\n";
}
