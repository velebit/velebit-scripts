#!/usr/bin/perl
use warnings;
use strict;
use open ':std', ':encoding(UTF-8)';

use File::Basename qw( dirname );

# ----------------------------------------------------------------------

# '--gain': do attempt to level the track gains using replaygain.
our $adjust_gain = 0;
# '--no-wipe': don't clear all ID3 tags from MP3 files (e.g. "Track 01" title).
our $wipe_id3    = 1;
# '--no-remove': don't remove everything in the old destination directory.
our $remove_old  = 1;


while (@ARGV and $ARGV[0] =~ /^-/) {
  $ARGV[0] eq '--no-gain' and $adjust_gain = 0, shift(@ARGV), next;
  $ARGV[0] eq '--gain' and $adjust_gain = 1, shift(@ARGV), next;
  $ARGV[0] eq '--no-wipe' and $wipe_id3 = 0, shift(@ARGV), next;
  $ARGV[0] eq '--no-remove' and $remove_old = 0, shift(@ARGV), next;
  die "Unknown argument '$ARGV[0]'";
}
#our $??? = shift @ARGV or die "too few args";
@ARGV and die "too many args";

# ----------------------------------------------------------------------

my %already_processed;
my %seen_outdir;

sub process_file ( $$ ) {
  my ($in, $out) = @_;
  my $outdir = dirname($out);
  $remove_old and ! $seen_outdir{$outdir}++
    and -e $outdir and (print("Removing $outdir\n"),
			system('rm', '-rf', $outdir)
			and die "rm -rf failed.\n");
  -d $outdir or (system('mkdir', '-p', $outdir)
		 and die "mkdir failed.\n");

  if (exists $already_processed{$in}) {
    if ($already_processed{$in} eq $out) {
      print STDERR "-!- $out\n";
    } else {
      print STDERR "-+- $out\n";
      system('cp', $already_processed{$in}, $out) and die "cp failed.\n";
    }
  } else {
    print STDERR "--- $out\n";
    system('cp', $in, $out) and die "cp failed.\n";
    if (/\.mp3$/i) {
      $wipe_id3 and (system("./id3wipe", '-f', $out)
		     and warn "id3wipe failed.\n");
      $adjust_gain and (system('replaygain', '-f', $out)
			and warn "replaygain failed.\n");
      $already_processed{$in} = $out;
    }
  }
  1;
}

# ----------------------------------------------------------------------

while (<>) {
  chomp;
  my ($in, $out) = split /=/, $_, 2;
  defined $out or die "bad input format: '$_'";
  process_file $in, $out;
}
