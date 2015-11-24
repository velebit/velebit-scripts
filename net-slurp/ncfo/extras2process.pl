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

my $SORTED = 0;
my @dir_entries;
while (@ARGV) {
  my $dir = shift @ARGV;
  ($dir eq '--sort' or $dir eq '-s') and $SORTED = 1, next;
  $dir eq '--' and last;
  my @files = glob "$dir/*";
  s,.*/,, for @files;
  my $name = $dir;  $name =~ s,.*/,,;  $name =~ s,.*\.,,;
  my ($entry) = grep $_->[0] eq $name, @dir_entries;
  if (! defined $entry) {
    push @dir_entries, [$name, []];
    ($entry) = grep $_->[0] eq $name, @dir_entries
      or die "internal error";
  }
  push @{$entry->[1]}, map "$dir/$_=../$name/$_", @files;
}

my @entries = <>;
s/\r?\n$// for @entries;

sub out_path ( $ ) { (split /=/, $_[0], 2)[1]; }

my @out_paths = map out_path($_), @entries;

my @extra_entries;
for my $entry (@dir_entries) {
  my $name = $entry->[0];
  if (scalar grep $_ =~ m!/\Q$name\E/!, @out_paths) {
    push @extra_entries, @{$entry->[1]};
  } else {
    print STDERR "Skipped extra: $_\n"
      for map out_path($_), @{$entry->[1]};
  }
}

push @entries, @extra_entries;
@entries = sort { out_path($a) cmp out_path($b) } @entries if $SORTED;
print "$_\n" for @entries;
