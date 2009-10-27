#!/usr/bin/perl
# Change the speed/tempo of a MIDI file.
# In other words, just like "midi-tweak --tempo" except it actually works.
#
use warnings;
use strict;
use MIDI;
use Getopt::Long;

### usage stuff

sub Usage ( @ ) {
  print STDERR join "\n\n", @_, <<EndOfUsage;
Usage:
  $0 [-s PERCENT[,PERCENT...]] infiles...
or:
  $0 -s PERCENT infile --to outfile
EndOfUsage
  exit 1;
}

use vars qw( @SPEED @OUTPUT );
GetOptions('speed|s=s'       => \@SPEED,
	   'output|o|to|t=s' => \@OUTPUT,
          ) or Usage;

@ARGV
  or  Usage "Error: you must specify at least one input file.";
@OUTPUT and (@ARGV != 1 or @OUTPUT != 1)
  and Usage "Error: you can't use --to with more than one file.";
@OUTPUT and @SPEED != 1
  and Usage "Error: you must specify -s exactly once when using --to.";

@SPEED = map split(/,/), @SPEED;
@SPEED = qw( 50 66.667 80 90 ) unless @SPEED;

### code to perform the MIDI speed modification

sub round ( $ ) { int($_[0] + .5); }

sub change_tempo ( $$$ ) {
  my ($in, $ratio, $out) = @_;

  my $opus = MIDI::Opus->new({from_file => $in}) or die;

  my @tracks = $opus->tracks;
  for my $t (0..$#tracks) {
    my $modified;
    use Data::Dumper;
    $_->[0] eq 'set_tempo' and $_->[2] = round($_->[2]*$ratio), ++$modified
      for $tracks[$t]->events;
    print "$modified tempo events modified in track $t.\n" if $modified;
    print "  (Why aren't they in track 0?)\n" if $modified and $t;
  }

  $opus->write_to_file($out);
  print "$out written.\n";
}

### do it!

sub make_output_name ( $$ ) {
  my ($file, $speed) = @_;
  $file =~ s/\.midi?$//i;
  $file =~ /_spd\d+$/
    and die("I refuse to auto-generate a file name for an already modified file"
	    . "\n    '$_[0]'\n ");
  $file . sprintf("_spd%03d.mid", $speed);
}

for my $input (@ARGV) {
  for my $speed (@SPEED) {
    my $output = shift @OUTPUT;
    $output = make_output_name $input, $speed unless defined $output;

    print "\n";
    change_tempo($input, 100/$speed, $output);
  }
}
print "\n";
