#!/usr/bin/perl
#
# usage: extras2process [dirs...] [-- input-files...]
#
# Takes a list of extras directories on the command line, and a list
# of already prepared processing directives on stdin.  The extras
# directories must be named "*.DEST" or "DEST", where DEST is the
# actual destination directory for the extras.
#
# The output is all of the directives seen on stdin, *plus* all of the
# corresponding extras.  Extras for directories not seen on stdin will
# be ignored, with a warning message.

use warnings;
use strict;

my %entries;
while (@ARGV) {
  my $dir = shift @ARGV;
  $dir eq '--' and last;
  my @files = glob "$dir/*";
  s,.*/,, for @files;
  my $name = $dir;  $name =~ s,.*/,,;  $name =~ s,.*\.,,;
  push @{$entries{$name}}, map "$dir/$_=../$name/$_", @files;
}

my @entries = <>;
s/\r?\n$// for @entries;

sub out_path ( $ ) { (split /=/, $_[0], 2)[1]; }

my @out_paths = map out_path($_), @entries;

my @extra_entries;
for my $name (sort keys %entries) {
  if (scalar grep $_ =~ m!/\Q$name\E/!, @out_paths) {
    push @extra_entries, @{$entries{$name}};
  } else {
    print STDERR "Skipped extra: $_\n"
      for map out_path($_), @{$entries{$name}};
  }
}

push @entries, @extra_entries;
print "$_\n" for sort { out_path($a) cmp out_path($b) } @entries;
