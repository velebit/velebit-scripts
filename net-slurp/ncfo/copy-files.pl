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

sub have_initial_match ( $@ ) {
  my ($expr, @texts) = @_;
  my ($first, @rest) = split //, $expr;
  my $regexp = join '', "^$first", map("(?:$_", @rest), (")?") x @rest, '$';
  $regexp =~ qr/$regexp/i;
  grep $_ =~ $regexp, @texts;
}

my $adjust_gain = ! have_initial_match('nogain', @ARGV);
my $wipe_id3    = ! have_initial_match('nowipe', @ARGV);

sub process ( $$$@ ) {
  my ($dest, $idx, $auth, @globs) = @_;
  my @files = map glob($_), map curly_expand($_), @globs;
  my $nfiles = @files;

  ! $nfiles
    and warn("*** ERROR: No files found for @globs\n"), return;
  $nfiles > 1
    and warn "--- WARNING: $nfiles files found with @globs [copying all]\n";

  for my $i (@files) {
    my $n = $i;
    $n =~ s,^.*/,,;
    print "[$n]\n";
    $n =~ s/^\d\d[-_ ]//;
    $n =~ s/^LT-//;
    $n =~ s/^(?:DH|AG|SH)_//;
    $n =~ s/\s/_/g;
    $n =~ s/_{2,}/_/g;

    -d $dest or (system('mkdir', '-p', $dest)
		 and die "mkdir failed.\n");

    #my $d = "$dest/${auth}_${idx}_$i";
    my $d = "$dest/${idx}_${auth}_$n";
    system('cp', $i, $d) and die "cp failed.\n";
    $wipe_id3 and (system("$ENV{HOME}/scripts/music/id3wipe", '-f', $d)
		   and warn "id3wipe failed.\n");
    $adjust_gain and (system('mp3gain', '-r', '-k', '-s', 's', '-q', $d)
		      and warn "mp3gain failed.\n");
  }
  1;
}

my $use_piano = 1;  # use the piano accompaniment MP3 if voice not available?
my $dir;
if (!@ARGV or have_initial_match('Kata', @ARGV)) {
  $dir = "../../Kata";
  system('rm', '-rf', $dir) and die "rm -rf $dir failed.\n";
  process $dir, '01', 'DH', '*Birth*melody*';
  process $dir, '02', 'DH', '*Eras*HiMelody*';
  process $dir, '03', 'DH', '*LivingLight*melody*';
  process $dir, '04', 'DH', '*Mutate*melody*'
    or ($use_piano and process $dir, '04', 'DH', '*Mutate*Orch*');
  process $dir, '05', 'DH', '*Reptiles*melody*';
  process $dir, '06', 'DH', '*Taxonomy*Sop*';
  process $dir, '07', 'DH', '*Axolotl*melody*';
  process $dir, '08', 'DH', '*Cetac{e,i}ans*melody*';
  process $dir, '09', 'DH', '*4E9Years*melody*';
  process $dir, '10', 'DH', '*Hedgehog*melody*';
  #process $dir, '11', 'DH', '*Virus*melody*';
  print "\n";
}

if (!@ARGV or have_initial_match('Abbe', @ARGV)) {
  $dir = "../../Abbe";
  system('rm', '-rf', $dir) and die "rm -rf $dir failed.\n";
  process $dir, '01', 'DH', '*Birth*Alto*'
    or ($use_piano and process $dir, '01', 'DH', '*Birth*Piano*');
  process $dir, '02', 'DH', '*Eras*AltoP*';
  process $dir, '03', 'DH', '*LivingLight*Alto*'
    or ($use_piano and process $dir, '03', 'DH', '*LivingLight*Piano*');
  process $dir, '04', 'DH', '*Mutate*melody*'
    or ($use_piano and process $dir, '04', 'DH', '*Mutate*Orch*');
  process $dir, '05', 'DH', '*Reptiles*melody*';
  process $dir, '06', 'DH', '*Taxonomy*Alto*';
  process $dir, '07', 'DH', '*Axolotl*melody*';
  process $dir, '08', 'DH', '*Cetac{e,i}ans*melody*';
  process $dir, '09', 'DH', '*4E9Years*Alto*'
    or ($use_piano and process $dir, '09', 'DH', '*FourBillion*Piano*');
  process $dir, '10', 'DH', '*Hedgehog*melody*';
  #process $dir, '11', 'DH', '*Virus*melody*';
  print "\n";
}

if (!@ARGV or have_initial_match('bert', @ARGV)) {
  $dir = "../../bert";
  system('rm', '-rf', $dir) and die "rm -rf $dir failed.\n";
  process $dir, '01', 'DH', '*Birth*Bass*'
    or ($use_piano and process $dir, '01', 'DH', '*Birth*Piano*');
  process $dir, '02', 'DH', '*Eras*Bass*';
  process $dir, '03', 'DH', '*LivingLight*Bass*'
    or ($use_piano and process $dir, '03', 'DH', '*LivingLight*Piano*');
  process $dir, '04', 'DH', '*Mutate*melody*'
    or ($use_piano and process $dir, '04', 'DH', '*Mutate*Orch*');
  process $dir, '05', 'DH', '*Reptiles*melody*';
  process $dir, '06', 'DH', '*Taxonomy*Bass*';
  process $dir, '07', 'DH', '*Axolotl*melody*';
  process $dir, '08', 'DH', '*Cetac{e,i}ans*melody*';
  process $dir, '09', 'DH', '*4E9Years*Bass*'
    or ($use_piano and process $dir, '09', 'DH', '*FourBillion*Piano*');
  process $dir, '10', 'DH', '*Hedgehog*melody*';
  #process $dir, '11', 'DH', '*Virus*melody*';
  print "\n";
}

if (!@ARGV or have_initial_match('demo', @ARGV)) {
  $dir = "../../demo";
  my $demo = "../../../../mp3/David*Haines/Lifetime*";
  system('rm', '-rf', $dir) and die "rm -rf $dir failed.\n";
  process $dir, '01', 'DH', "$demo/*Birth*";
  process $dir, '02', 'DH', "$demo/*Eras*";
  process $dir, '03', 'DH', "$demo/*Living*Light*";
  process $dir, '04', 'DH', "$demo/*Mutate*";
  process $dir, '05', 'DH', "$demo/*Reptiles*";
  process $dir, '06', 'DH', "$demo/*Taxonomy*";
  process $dir, '07', 'DH', "$demo/*Axolotl*";
  process $dir, '08', 'DH', "$demo/*Cetac{e,i}ans*";
  process $dir, '09', 'DH', "$demo/*Four*Billion*";
  process $dir, '10', 'DH', "$demo/*Hedgehog*";
  process $dir, '11', 'DH', "$demo/*Virus*";
  print "\n";
}
