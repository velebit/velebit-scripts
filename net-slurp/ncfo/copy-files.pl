#!/usr/bin/perl
use warnings;
use strict;

chdir 'mp3' or die "chdir(mp3): $!";

sub _add_prefix ( $$ ) { map $_[0] . $_, @{$_[1]}; }

sub curly_expand ( $ ) {
  my ($expr) = @_;
  my @parts = split /(\{.*?\})/, $expr;
  @parts > 1 or return $expr;
  my @opts = map([ /^\{(.*)\}$/ ? split(/,/, $1, -1) : $_ ],
		 grep length, @parts);

  my @results = @{ pop @opts };
  while (@opts) {
    @results = map _add_prefix($_, \@results), @{ pop @opts };
  }

  @results;
}

sub case_expand ( $ ) {
  my ($expr) = @_;
  $expr =~ s/(\w)/\[\u$1\l$1\]/ig;
  $expr;
}

sub initial_match_regexp ( $ ) {
  my ($expr) = @_;
  my ($first, @rest) = split //, $expr;
  join '', "\Q$first", map("(?:\Q$_", @rest), (")?") x @rest;
}

sub have_initial_match ( $@ ) {
  my ($expr, @texts) = @_;
  my $regexp = join '|', map initial_match_regexp($_), split /,/, $expr;
  $regexp = qr/^(?:$regexp)$/i;
  grep $_ =~ $regexp, @texts;
}

# 'nogain': don't attempt to level the track gains using mp3gain.
my $adjust_gain = ! have_initial_match('nogain', @ARGV);
# 'nowipe': don't clear all ID3 tags from MP3 files (e.g. "Track 01" titles).
my $wipe_id3    = ! have_initial_match('nowipe', @ARGV);
# 'nopiano': don't use the piano accompaniment MP3 when voice not available.
my $use_piano   = ! have_initial_match('nopiano', @ARGV);

sub filename_only ( $ ) {
  my ($file) = @_;
  $file =~ s,^.*/,,;
  $file;
}

sub base_filename ( $ ) {
  my ($file) = @_;
  $file = filename_only $file;
  $file =~ s/^\d\d[-_ ]//;
  $file =~ s/^LT-//;
  $file =~ s/^(?:DH|AG|SH)_//;
  $file =~ s/\s/_/g;
  $file =~ s/_{2,}/_/g;
  $file;
}

sub uniform_filename ( $$$ ) {
  my ($idx, $auth, $file) = @_;
  my $base = base_filename $file;
  "${idx}_${auth}_${base}";
}

sub show ( $$$@ ) {
  my ($dest, $idx, $auth, @globs) = @_;
  my @files = map glob($_), map case_expand($_), map curly_expand($_), @globs;
  #@files = map filename_only($_), @files;
  @files = map base_filename($_), @files;
  #@files = map uniform_filename($idx, $auth, $_), @files;

  print "--- matching files for @globs ---\n";

  if (! @files) {
    print "*** ERROR: No files found!\n";
    return;
  }

  print "$_\n" for @files;
  1;
}

my %already_processed;

sub process ( $$$@ ) {
  my ($dest, $idx, $auth, @globs) = @_;
  my @files = map glob($_), map case_expand($_), map curly_expand($_), @globs;
  my $nfiles = @files;

  ! $nfiles
    and warn("*** ERROR: No files found for @globs\n"), return;
  $nfiles > 1
    and warn "--- WARNING: $nfiles files found with @globs [copying all]\n";

  for my $i (@files) {
    my $n = base_filename $i;
    print "[$n]\n";
    my $u = uniform_filename $idx, $auth, $n;

    -d $dest or (system('mkdir', '-p', $dest)
		 and die "mkdir failed.\n");

    #my $d = "$dest/${auth}_${idx}_$i";
    my $d = "$dest/$u";
    if (exists $already_processed{$i}) {
      #warn "USING SHORTCUT for $d\n"; # <- $already_processed{$i}\n";
      system('cp', $already_processed{$i}, $d) and die "cp failed.\n";
    } else {
      system('cp', $i, $d) and die "cp failed.\n";
      $wipe_id3 and (system("$ENV{HOME}/scripts/music/id3wipe", '-f', $d)
		     and warn "id3wipe failed.\n");
      $adjust_gain and (system('mp3gain', '-r', '-k', '-s', 's', '-q', $d)
			and warn "mp3gain failed.\n");
      $already_processed{$i} = $d;
    }
  }
  1;
}

my $dir;
if (have_initial_match('show', @ARGV)) {
  $dir = undef;
  show $dir, '01', 'DH', '*Birth*';
  show $dir, '02', 'DH', '*Eras*';
  show $dir, '03', 'DH', '*LivingLight*';
  show $dir, '04', 'DH', '*Mutate*';
  show $dir, '05', 'DH', '*Reptiles*';
  show $dir, '06', 'DH', '*Taxonomy*';
  show $dir, '07', 'DH', '*Axolotl*';
  show $dir, '08', 'DH', '*Cetac{e,i}ans*';
  show $dir, '09', 'DH', '*4E9Years*', '*Four*Billion*';
  show $dir, '10', 'DH', '*Hedgehog*';
  show $dir, '11', 'DH', '*Virus*';
  show $dir, '12', 'DH', '*Darwin*';
  show $dir, '13', 'DH', '*Queen*Bee*';
  show $dir, '14', 'DH', '*Life*That*Lives*';
  show $dir, '15', 'DH', '*Extremophile*';
  show $dir, '16', 'GT', '*DNA*';
  show $dir, '17', 'GT', '*Octopus*';
  print "\n";
}

if (!@ARGV or have_initial_match('Kata,all', @ARGV)) {
  $dir = "../../Kata";
  print "=== preparing $dir ===\n";
  system('rm', '-rf', $dir) and die "rm -rf $dir failed.\n";
  process $dir, '01', 'DH', '*Birth*melody*';
  process $dir, '02', 'DH', '*Eras*HiMelody*';
  process $dir, '03', 'DH', '*LivingLight*melody*';
  process $dir, '04', 'DH', '*Mutate*melody*';
  process $dir, '05', 'DH', '*Reptiles*melody*';
  process $dir, '06', 'DH', '*Taxonomy*Alt*';
  process $dir, '07', 'DH', '*Axolotl*melody*';
  process $dir, '08', 'DH', '*Cetac{e,i}ans*melody*';
  process $dir, '09', 'DH', '*4E9Years*melody*';
  process $dir, '10a', 'DH', '*Hedgehog*melody*'; # no Tutti for Kata
  process $dir, '11', 'DH', '*Virus*Practice*';
  process $dir, '12', 'DH', '*Darwin*melody*';
  process $dir, '13', 'DH', '*Queen*Bee*melody*';
  process $dir, '14', 'DH', '*Life*That*Lives*Chorus*';
  process $dir, '15', 'DH', '*Extremophile*melody*';
  process $dir, '16', 'GT', '*DNA*Sop*';
  process $dir, '17', 'GT', '*Octopus*melody*';
  print "\n";
}

if (have_initial_match('Sue,all', @ARGV)) {
  $dir = "../../other/Sue";
  print "=== preparing $dir ===\n";
  system('rm', '-rf', $dir) and die "rm -rf $dir failed.\n";
  process $dir, '01', 'DH', '*Birth*Stf3*';  # different!
  process $dir, '02', 'DH', '*Eras*HiMelody*';
  process $dir, '03', 'DH', '*LivingLight*melody*';
  process $dir, '04', 'DH', '*Mutate*melody*';
  process $dir, '05', 'DH', '*Reptiles*melody*';
  process $dir, '06', 'DH', '*Taxonomy*Sop*';  # different!
  process $dir, '07', 'DH', '*Axolotl*melody*';
  process $dir, '08', 'DH', '*Cetac{e,i}ans*melody*';
  process $dir, '08x', 'DH', '../../midi-stuff/*Cetaceans*all*.mp3';
  process $dir, '09', 'DH', '*4E9Years*Sop*';  # different!
  process $dir, '10a', 'DH', '*Hedgehog*melody*';
  process $dir, '10b', 'DH', '*Hedgehog*Harmony*';
  process $dir, '10c', 'DH', '*Hedgehog*Tutti*';
  process $dir, '11', 'DH', '*Virus*Practice*';
  process $dir, '12', 'DH', '*Darwin*melody*';
  process $dir, '13', 'DH', '*Queen*Bee*harmony*';
  process $dir, '14', 'DH', '*Life*That*Lives*Chorus*';
  process $dir, '15', 'DH', '*Extremophile*melody*';
  process $dir, '16', 'GT', '*DNA*Sop*';
  process $dir, '17', 'GT', '*Octopus*melody*';
  print "\n";
}

if (!@ARGV or have_initial_match('Abbe,all', @ARGV)) {
  $dir = "../../Abbe";
  print "=== preparing $dir ===\n";
  system('rm', '-rf', $dir) and die "rm -rf $dir failed.\n";
  process $dir, '01', 'DH', '*Birth*Stf4*';
  process $dir, '02', 'DH', '*Eras*AltoP*';
  process $dir, '03', 'DH', '*LivingLight*Alto*'
    or ($use_piano and process $dir, '03', 'DH', '*LivingLight*Piano*');
  process $dir, '04', 'DH', '*Mutate*Alto*'
    or process $dir, '04', 'DH', '../../midi-stuff/*Mutate*alto*.mp3';
  process $dir, '05', 'DH', '*Reptiles*melody*';
  process $dir, '06', 'DH', '*Taxonomy*Alto*';
  process $dir, '07', 'DH', '*Axolotl*melody*';
  process $dir, '08', 'DH', '*Cetac{e,i}ans*Alt*'
    or process $dir, '08', 'DH', '../../midi-stuff/*Cetaceans*alto*.mp3';
  process $dir, '08x', 'DH', '../../midi-stuff/*Cetaceans*all*.mp3';
  process $dir, '09', 'DH', '*4E9Years*melody*';
  process $dir, '10a', 'DH', '*Hedgehog*melody*';
  process $dir, '10b', 'DH', '*Hedgehog*Harmony*';
  process $dir, '10c', 'DH', '*Hedgehog*Tutti*';
  process $dir, '11', 'DH', '*Virus*Practice*';
  process $dir, '12', 'DH', '*Darwin*melody*';
  process $dir, '12x', 'DH', '../../midi-stuff/*Darwin*alto*.mp3';
  process $dir, '13', 'DH', '*Queen*Bee*low*';
  process $dir, '14', 'DH', '*Life*That*Lives*Chorus*';
  process $dir, '15', 'DH', '*Extremophile*melody*';
  process $dir, '16', 'GT', '*DNA*Alt*';
  process $dir, '17', 'GT', '*Octopus*HarmonyLow*';
  print "\n";
}

if (!@ARGV or have_initial_match('bert,all', @ARGV)) {
  $dir = "../../bert";
  print "=== preparing $dir ===\n";
  system('rm', '-rf', $dir) and die "rm -rf $dir failed.\n";
  process $dir, '01', 'DH', '*Birth*Bass*';
  process $dir, '02', 'DH', '*Eras*Bass*';
  process $dir, '03', 'DH', '*LivingLight*Bass*'
    or process $dir, '03', 'DH', '../../midi-stuff/*LivingLight*bass*.mp3'
    or ($use_piano and process $dir, '03', 'DH', '*LivingLight*Piano*');
  process $dir, '04', 'DH', '*Mutate*Bass*'
    or process $dir, '04', 'DH', '../../midi-stuff/*Mutate*bass*.mp3';
  process $dir, '05', 'DH', '*Reptiles*melody*';
  process $dir, '06', 'DH', '*Taxonomy*Bass*';
  process $dir, '07', 'DH', '*Axolotl*melody*';
  process $dir, '08', 'DH', '*Cetac{e,i}ans*Bass*'
    or process $dir, '08', 'DH', '../../midi-stuff/*Cetaceans*bass*.mp3';
  process $dir, '08x', 'DH', '../../midi-stuff/*Cetaceans*all*.mp3';
  process $dir, '09', 'DH', '*4E9Years*Bass*';
  process $dir, '10a', 'DH', '*Hedgehog*melody*';
  process $dir, '10b', 'DH', '*Hedgehog*Harmony*';
  process $dir, '10c', 'DH', '*Hedgehog*Tutti*';
  process $dir, '11', 'DH', '*Virus*Practice*';
  process $dir, '12', 'DH', '*Darwin*melody*';
  process $dir, '12x', 'DH', '../../midi-stuff/*Darwin*bass*.mp3';
  process $dir, '13', 'DH', '*Queen*Bee*melody*';
  process $dir, '14', 'DH', '*Life*That*Lives*Chorus*';
  process $dir, '15', 'DH', '*Extremophile*Baritone*';
  process $dir, '16', 'GT', '*DNA*Alt*';
  process $dir, '17', 'GT', '*Octopus*Melody*';
  print "\n";
}

if (!@ARGV or have_initial_match('demo,all', @ARGV)) {
  $dir = "../../demo";
  print "=== preparing $dir ===\n";
  my $demo = "../../../../mp3/David*Haines/Lifetime*";
  system('rm', '-rf', $dir) and die "rm -rf $dir failed.\n";
  process $dir, '01', 'DH', "$demo/*Birth*";
  process $dir, '02', 'DH', "$demo/*Eras*";
  process $dir, '03', 'DH', "$demo/*Living*Light*";
  process $dir, '04', 'DH', "$demo/*Mutate*";
  process $dir, '05', 'DH', "$demo/*Reptiles*";
  process $dir, '06', 'DH', "$demo/*Taxonomy*";
  #process $dir, '07', 'DH', "$demo/*Axolotl*";
  process $dir, '08', 'DH', "$demo/*Cetac{e,i}ans*";
  process $dir, '09', 'DH', "$demo/*Four*Billion*";
  process $dir, '10', 'DH', "$demo/*Hedgehog*";
  #process $dir, '11', 'DH', "$demo/*Virus*";
  process $dir, '12', 'DH', "$demo/*Darwin*";
  process $dir, '13', 'DH', "$demo/*Queen*Bee*";
  #process $dir, '14', 'DH', "$demo/*Life*That*Lives*";
  #process $dir, '15', 'DH', "$demo/*Extremophile*";
  #process $dir, '16', 'GT', "$demo/*DNA*";
  #process $dir, '17', 'GT', "$demo/*Octopus*";
  print "\n";
}
