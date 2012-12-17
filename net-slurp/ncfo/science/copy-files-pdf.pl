#!/usr/bin/perl
use warnings;
use strict;

chdir 'pdf' or die "chdir(pdf): $!";

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
  }
  1;
}

my $dir = "../../pdf";
system('rm', '-rf', $dir) and die "rm -rf $dir failed.\n";
process $dir, '01', 'DH', 'Ancestral*';
process $dir, '02', 'DH', 'Reflex*';
process $dir, '03', 'xx', 'Mirror*';
process $dir, '04', 'LM', 'Beauty*';
process $dir, '05', 'xx', '{,A}Tower*';
process $dir, '06', 'LM', 'Barks*';
process $dir, '07', 'DH', 'Lan{g,}uage*';
process $dir, '08', 'DH', 'SoundSight*';
process $dir, '09', 'xx', '{,A_}Para*';
process $dir, '10', 'LM', 'Faster*';
