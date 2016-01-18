#!/usr/bin/perl
#
# usage: extras2process [dirs...] [-- directive-files...]
#
# Takes a list of extras directories on the command line, and a list
# of already prepared processing directives on stdin.  The names of
# the extras directories must be in one of the following formats:
#     **/*.DEST/first
#     **/*.DEST/before.MATCH
#     **/*.DEST/after.MATCH
#     **/*.DEST/last
#     **/*.DEST
# where "DEST" is the actual destination directory for the extras
# (which must not include periods), "MATCH" is a string to match in
# the input directives, "*." is an optional string prefix and "**/" is
# an optional path.  For files in *.DEST, "last" is implied.
#
# The output is all of the directives seen on stdin, *plus* all of the
# corresponding extras.  Extras for directories not seen on stdin will
# be ignored, with a warning message.

use warnings;
use strict;

my $SORTED = 0;
my (@match_before_entries, @match_after_entries);

sub file ( $ ) { my ($f) = @_;  $f =~ s,.*/,,;  $f; }

while (@ARGV) {
  my $dir = shift @ARGV;
  ($dir eq '--sort' or $dir eq '-s') and $SORTED = 1, next;
  $dir eq '--' and last;
  $dir =~ /-gain$/ and next;  # skip gain cache directories
  my $dest = $dir;  $dest =~ s,.*/,,;  $dest =~ s,.*\.,,;
  {
    my @files = grep -f, glob "$dir/first/*";
    push @match_before_entries, [qr!=\.\./\Q$dest\E/!,
				 [map "$_=../$dest/" . file($_), @files]]
      if @files;
  }
  for my $d (grep -d, glob "$dir/before.*") {
    my $re = join '.*', split /\+/, ((split /\./, file($d), 2)[1]);
    my @files = grep -f, glob "$d/*";
    push @match_before_entries, [qr!=\.\./\Q$dest\E/.*$re!,
				 [map "$_=../$dest/" . file($_), @files]]
      if @files;
  }
  for my $d (grep -d, glob "$dir/after.*") {
    my $re = join '.*', split /\+/, ((split /\./, file($d), 2)[1]);
    my @files = grep -f, glob "$d/*";
    push @match_after_entries, [qr!=\.\./\Q$dest\E/.*$re!,
				 [map "$_=../$dest/" . file($_), @files]]
      if @files;
  }
  {
    my @files = grep -f, glob "$dir/last/*";
    push @match_after_entries, [qr!=\.\./\Q$dest\E/!,
				[map "$_=../$dest/" . file($_), @files]]
      if @files;
  }
  {
    my @files = grep -f, glob "$dir/*";
    push @match_after_entries, [qr!=\.\./\Q$dest\E/!,
				[map "$_=../$dest/" . file($_), @files]]
      if @files;
  }
}

my @entries = <>;
s/\r?\n$// for @entries;

sub in_path ( $ ) { (split /=/, $_[0], 2)[0]; }
sub out_path ( $ ) { (split /=/, $_[0], 2)[1]; }

sub add_matches_before ( $$ ) {
  my ($entries, $match_entries) = @_;
  my @results;
  for my $entry (@$entries) {
  MATCH:
    for my $match (@$match_entries) {
      my $re = $match->[0];
      defined $re or next MATCH;
      if ($entry =~ m!$re!) {
	push @results, @{$match->[1]};
	$match->[0] = undef;
      }
    }
    push @results, $entry;
  }
  @results;
}

sub add_matches_after ( $$ ) {
  my ($entries, $match_entries) = @_;
  reverse add_matches_before [reverse @$entries], $match_entries;
}


@entries = add_matches_before(\@entries, \@match_before_entries);
@entries = add_matches_after(\@entries, \@match_after_entries);
@entries = sort { out_path($a) cmp out_path($b) } @entries if $SORTED;
print "$_\n" for @entries;

print STDERR "Skipped extra file: $_\n"
  for map out_path($_), map @{$_->[1]},
    grep defined($_->[0]), (@match_before_entries, @match_after_entries);
