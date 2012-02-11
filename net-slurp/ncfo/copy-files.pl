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

sub process ( $$$@ ) {
  my ($dest, $idx, $auth, @globs) = @_;
  my @files = map glob($_), map curly_expand($_), @globs;
  my $nfiles = @files;

  ! $nfiles
    and warn("*** ERROR: No files found for @globs\n"), return;
  $nfiles > 1
    and warn "--- WARNING: $nfiles files found with @globs [copying all]\n";

  for my $i (@files) {
    print "[$i]\n";
    -d $dest or (system('mkdir', '-p', $dest)
		 and die "mkdir failed.\n");

    #my $d = "$dest/${auth}_${idx}_$i";
    my $n = $i;
    $n =~ s/^LT-//;
    $n =~ s/^DH_//;
    my $d = "$dest/${idx}_${auth}_$n";
    system('cp', $i, $d) and die "cp failed.\n";
    $adjust_gain and (system('mp3gain', '-r', '-k', '-s', 's', '-q', $d)
		      and die "mp3gain failed.\n");
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
  process $dir, '08', 'DH', '*Cetac[ei]ans*melody*';
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
  process $dir, '02', 'DH', '*Eras*Alto*';
  process $dir, '03', 'DH', '*LivingLight*Alto*'
    or ($use_piano and process $dir, '03', 'DH', '*LivingLight*Piano*');
  process $dir, '04', 'DH', '*Mutate*Alto*'
    or ($use_piano and process $dir, '04', 'DH', '*Mutate*Orch*');
  process $dir, '05', 'DH', '*Reptiles*melody*';
  process $dir, '06', 'DH', '*Taxonomy*Alto*';
  process $dir, '07', 'DH', '*Axolotl*melody*';
  process $dir, '08', 'DH', '*Cetac[ei]ans*melody*';
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
  process $dir, '04', 'DH', '*Mutate*Bass*'
    or ($use_piano and process $dir, '04', 'DH', '*Mutate*Orch*');
  process $dir, '05', 'DH', '*Reptiles*melody*';
  process $dir, '06', 'DH', '*Taxonomy*Bass*';
  process $dir, '07', 'DH', '*Axolotl*melody*';
  process $dir, '08', 'DH', '*Cetac[ei]ans*melody*';
  process $dir, '09', 'DH', '*4E9Years*Bass*'
    or ($use_piano and process $dir, '09', 'DH', '*FourBillion*Piano*');
  process $dir, '10', 'DH', '*Hedgehog*melody*';
  #process $dir, '11', 'DH', '*Virus*melody*';
  print "\n";
}

if (0 and (!@ARGV or have_initial_match('demo', @ARGV))) {
  $dir = "../../demo";
  system('rm', '-rf', $dir) and die "rm -rf $dir failed.\n";
  process $dir, '01', 'DH', '*performance*Xxx*';
}
