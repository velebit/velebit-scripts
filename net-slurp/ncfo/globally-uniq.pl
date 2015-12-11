#!/usr/bin/perl
#
# usage: globally-uniq
#
# Reads text on stdin, and outputs each line on stdout unless it has
# already been encountered.
use warnings;
use strict;
use Getopt::Long;

# allow Unicode (utf8-encoded) console output
BEGIN {
  binmode(STDOUT, ":utf8");
  binmode(STDERR, ":utf8");
};

my $script = $0;  $script =~ s,.*[/\\],,;

my ($LINES, $DST_FILES, $SRC_FILES_PER_DEST_DIR);

GetOptions('lines|l!' => \$LINES,
	   'destination-files|df!' => \$DST_FILES,
	   'source-files-per-destination-directory|sfdd!' => \$SRC_FILES_PER_DEST_DIR,
          ) or die "Usage: $script [-l|-df|-sfdd] [FILES...]\n";
!defined $LINES and !defined $DST_FILES and !defined $SRC_FILES_PER_DEST_DIR
  and $LINES = 1;

my (%seen_lines, %seen_df, %seen_dd_sf);

while (<>) {
  my $orig = $_;

  s/\r?\n$//;

  my ($src, $dst) = split /=/, $_, 2;

  my ($src_dir, $src_file) = ($src =~ m,^(.+)/([^/]+)$,);
  defined $src_dir
    or warn("No directory found in '$src'"), $src_dir = '.';
  1 while $src_dir =~ s,^\./,,;
  1 while $src_dir =~ s,/\./,/,;
  $src_dir =~ s,//+,/,g;

  my ($dst_dir, $dst_file) = ($dst =~ m,^(.+)/([^/]+)$,);
  defined $dst_dir
    or warn("No directory found in '$dst'"), $dst_dir = '.';
  1 while $dst_dir =~ s,^\./,,;
  1 while $dst_dir =~ s,/\./,/,;
  $dst_dir =~ s,//+,/,g;

  $LINES and $seen_lines{$_}++ and next;
  $DST_FILES and $seen_df{$dst}++ and next;
  $SRC_FILES_PER_DEST_DIR and $seen_dd_sf{$dst_dir}{$src}++ and next;

  print $orig;
}
