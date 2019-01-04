#!/usr/bin/perl
#
# usage: extras2process [dirs...] [-- directive-files...]
#
# Takes a list of extras directories on the command line, and a list
# of already prepared processing directives on stdin (or in specified
# directive-files, if any).  The output will be all of the directives
# seen on stdin, *plus* all of the corresponding extras.  Extras for
# directories not seen on stdin will be ignored, with a warning
# message.
#
# The extras directories must contain the extra entries as files or
# symbolic links, within subdirectories named according to one of the
# following formats:
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
# The "+" character in MATCH separates phrases, and implies a ".*"
# regexp match.
#
# A leading "seq{number}." prefix is stripped from all files/links if
# present.  The result is used as the name of the output file.
#
# For example, if invoked as
#     extras2process.pl mp3-extras.bert
# and the mp3-extras.bert tree contains the file or link
#     mp3-extras.bert/after.Some Track+without me/seq0.extra Some Track.mp3
# and the stdin contains the line
#     mp3/SomeTrack_NoMe.mp3=../bert/Some Track (without me).mp3
# (and nothing else matches), the output will contain
#     mp3/SomeTrack_NoMe.mp3=../bert/Some Track (without me).mp3
#     mp3-extras.bert/after.Some Track+without me/seq0.extra Some Track.mp3=../bert/extra Some Track.mp3

use warnings;
use strict;
use POSIX qw( ENOENT );

my $SORTED = 0;
my (@match_before_entries, @match_after_entries);

sub file ( $ ) { my ($f) = @_;  $f =~ s,.*/,,;  $f; }
sub canon_out ( $ ) { my ($o) = file $_[0];  $o =~ s,^seq\d+[. ],,;  $o; }

sub get_dir_contents ( $ ) {
  my ($d) = @_;
  my $DH;
  if (! opendir $DH, $d) {
    return if $! == ENOENT;
    die "opendir($d): $!";
  }
  my @f = map "$d/$_", grep ! /^\.\.?$/, readdir $DH;
  @f;
}

while (@ARGV) {
  my $dir = shift @ARGV;
  ($dir eq '--sort' or $dir eq '-s') and $SORTED = 1, next;
  $dir eq '--' and last;
  $dir =~ /-gain$/ and next;  # skip gain cache directories
  my $dest = $dir;  $dest =~ s,.*/,,;  $dest =~ s,.*\.,,;
  {
    my @files = sort grep -f, get_dir_contents "$dir/first";
    push @match_before_entries, [qr!=\.\./\Q$dest\E/!,
				 [map "$_=../$dest/" . canon_out($_), @files]]
      if @files;
  }
  for my $d (sort grep -d && m,/before\.,, get_dir_contents $dir) {
    my $re = join '.*', split /\+/, ((split /\./, file($d), 2)[1]);
    my @files = sort grep -f, get_dir_contents $d;
    push @match_before_entries, [qr!=\.\./\Q$dest\E/.*$re!,
				 [map "$_=../$dest/" . canon_out($_), @files]]
      if @files;
  }
  for my $d (sort grep -d && m,/after\.,, get_dir_contents $dir) {
    my $re = join '.*', split /\+/, ((split /\./, file($d), 2)[1]);
    my @files = sort grep -f, get_dir_contents $d;
    push @match_after_entries, [qr!=\.\./\Q$dest\E/.*$re!,
				 [map "$_=../$dest/" . canon_out($_), @files]]
      if @files;
  }
  {
    my @files = sort grep -f, get_dir_contents "$dir/last";
    push @match_after_entries, [qr!=\.\./\Q$dest\E/!,
				[map "$_=../$dest/" . canon_out($_), @files]]
      if @files;
  }
  {
    my @files = sort grep -f, get_dir_contents $dir;
    push @match_after_entries, [qr!=\.\./\Q$dest\E/!,
				[map "$_=../$dest/" . canon_out($_), @files]]
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
  my $reverse_entries =
    [ map [$_->[0], [reverse @{$_->[1]}]], reverse @$match_entries ];
  my @entries =
    reverse add_matches_before [reverse @$entries], $reverse_entries;
  # update used status
  defined $reverse_entries->[$_][0]
    or $match_entries->[$#$reverse_entries - $_][0] = undef
      for 0..$#$reverse_entries;
  @entries;
}


@entries = add_matches_before(\@entries, \@match_before_entries);
@entries = add_matches_after(\@entries, \@match_after_entries);
@entries = sort { out_path($a) cmp out_path($b) } @entries if $SORTED;
print "$_\n" for @entries;

print STDERR "Skipped extra file: $_\n"
  for map out_path($_), map @{$_->[1]},
    grep defined($_->[0]), (@match_before_entries, @match_after_entries);
