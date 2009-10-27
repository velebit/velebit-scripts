#!/usr/bin/perl
use warnings;
use strict;
use MIDI;

sub slow_down( $$$ );

for my $v ( qw( alto bass ) ) {
  for my $p ( qw( 5_m851-end ) ) {
    for my $spd (50, 67, 75) {
      #print "... v=$v spd=$spd\n";

      # midi-tweak doesn't work for cyberbass.com files.  Hate hate hate.
#      system('/home/bert/perl-lib/bin/midi-tweak', '--tempo',
#	     '--ratio', 100/$spd, '--ident',
#	     '--output', "$v/${v}_${p}_spd0${spd}.mid", "$v/${v}_${p}.mid");

      my $spdx = sprintf "%03d", $spd;
      print "\n";
      slow_down("$v/${v}_${p}.mid", 100/$spd, "$v/${v}_${p}_spd${spdx}.mid");
    }
  }
}
print "\n";

sub round ( $ ) { int($_[0] + .5); }

sub slow_down ( $$$ ) {
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
