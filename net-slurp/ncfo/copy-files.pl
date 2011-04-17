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
    my $d = "$dest/${idx}_${auth}_$i";
    system('cp', $i, $d) and die "cp failed.\n";
    $adjust_gain and (system('mp3gain', '-r', '-k', '-s', 's', '-q', $d)
		      and die "mp3gain failed.\n");
  }
  1;
}

my $dir;
if (!@ARGV or have_initial_match('Kata', @ARGV)) {
  $dir = "../../Kata";
  system('rm', '-rf', $dir) and die "rm -rf $dir failed.\n";
  process $dir, '01', 'DH', 'Ancestral*Sop*';
  process $dir, '02', 'DH', 'Reflex*Soprano*';
  process $dir, '03', 'xx', 'Mirror*HiSoprano*';
  process $dir, '04', 'LM', 'Beauty*Kids*';
  process $dir, '05', 'xx', '{,A}Tower*KidsHi_3*';
  process $dir, '06', 'LM', 'Barks*Kids*';
  process $dir, '07', 'DH', 'Lan{g,}uage*Soprano*';
  process $dir, '08', 'DH', 'SoundSight*Soprano*';
  process $dir, '09', 'xx', '{,A_}Para*Soprano*';
  process $dir, '10', 'LM', 'Faster*Hi*';
  print "\n";
}

if (!@ARGV or have_initial_match('Abbe', @ARGV)) {
  $dir = "../../Abbe";
  system('rm', '-rf', $dir) and die "rm -rf $dir failed.\n";
  process $dir, '01', 'DH', 'Ancestral*Alto*';
  process $dir, '02', 'DH', 'Reflex*Alto*';
  process $dir, '03', 'xx', 'Mirror*Alto*';
  process $dir, '04', 'LM', 'Beauty*Alto*';
  process $dir, '05', 'xx', '{,A}Tower*Alto*';
  process $dir, '06', 'LM', 'Barks*Alto*';
  process $dir, '07', 'DH', 'Lan{g,}uage*Alto*';
  process $dir, '08', 'DH', 'SoundSight*Alto*';
  process $dir, '09', 'xx', '{,A_}Para*Alto*';
  process $dir, '10', 'LM', 'Faster*Lo*';
  print "\n";
}

if (!@ARGV or have_initial_match('bert', @ARGV)) {
  $dir = "../../bert";
  system('rm', '-rf', $dir) and die "rm -rf $dir failed.\n";
  process $dir, '01', 'DH', 'Ancestral*Bass*';
  process $dir, '02', 'DH', 'Reflex*Baritone*';
  process $dir, '03', 'xx', 'Mirror*Bass*';
  process $dir, '04', 'LM', 'Beauty*n_Baritone*'
    or process $dir, '04', 'LM', 'Beauty*Baritone*';
  process $dir, '05', 'xx', '{,A}Tower*Bass*';
  process $dir, '06', 'LM', 'Barks*Bass*', 'Barks*SopranoHi*';
  process $dir, '07', 'DH', 'Lan{g,}uage*Baritone*';
  process $dir, '08', 'DH', 'SoundSight*Tenor*';
  process $dir, '09', 'xx', '{,A_}Para*Bass*';
  process $dir, '10', 'LM', 'Faster*Lo*';
  print "\n";
}

if (!@ARGV or have_initial_match('demo', @ARGV)) {
  $dir = "../../demo";
  system('rm', '-rf', $dir) and die "rm -rf $dir failed.\n";
  process $dir, '01', 'DH', '*performance*Ancestral*'
    or process $dir, '01', 'DH', 'Ancestral*Demo*';
  process $dir, '02', 'DH', '*performance*Reflex*'
    or process $dir, '02', 'DH', 'Reflex*Demo*';
  #process $dir,      '03', 'xx', '*performance*Mirror*' or
  process $dir, '03', 'xx', 'Mirror*Demo*'
    or process $dir, '03', 'xx', 'Mirror*Piano*';
  #process $dir, '04', 'LM', '*performance*Beauty*'
  process $dir, '04', 'LM', 'Beauty*Demo*';
  #process $dir, '05', 'xx', '*performance*{,A}Tower*' or
  process $dir, '05', 'xx', '{,A}Tower*Demo*';
  #process $dir, '06', 'LM', '*performance*Barks*' or
  process $dir, '06', 'LM', 'Barks*Demo*';
  process $dir, '07', 'DH', '*performance*Lan{g,}uage*'
    or process $dir, '07', 'DH', 'Lan{g,}uage*Demo*';
  process $dir, '08', 'DH', '*performance*AnimalChat*'
    or process $dir, '08', 'DH', 'SoundSight*Demo*';
  #process $dir, '09', 'xx', '*performance*{,A_}Para*' or
  process $dir, '09', 'xx', '{,A_}Para*Demo*';
  #process $dir, '10', 'LM', '*performance*Faster*All*' or
  process $dir, '10', 'LM', 'Faster*All*';
}
