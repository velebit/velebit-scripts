#!/usr/bin/perl
use warnings;
use strict;
use File::Basename qw( dirname );

# Create the list of 'codes' to generate symlinks from.
# A-E = unique letter, O = shared letter, X = no symlink

my $NUM_TREES = 5;
my @codes = ( '' );
my $letter = 'A';
@codes = map( ( $_ . $letter, $_ . 'O', $_ . 'X' ), @codes ), ++$letter
  for 1..$NUM_TREES;
# All Xes means no symlinks.  One O isn't the same as anything else.
@codes = grep(/[^X]/ && (!/O/ || /O.*O/), @codes);

# Write the symlinks

my $root = "tdts-$NUM_TREES";
system "rm -rf $root";
mkdir $root or die "mkdir($root): $!";
chdir $root or die "chdir($root): $!";

for my $n (1..$NUM_TREES) {
  mkdir "d$n" or die "mkdir(d$n): $!";
  for my $c (@codes) {
    my @cx = split //, $c;
    my $here = $cx[$n-1];
    $here eq 'X' and next;
    symlink "test_$here", "d$n/$c.sym" or die "symlink($c.sym): $!";
  }
}

# Generate the expected output

open my $OUT, '>', 'expected.out' or die "open(expected.out): $!";

for my $c (@codes) {
  my @cx = split //, $c;
  print $OUT "d$_/$c.sym: does not exist.\n"
    for grep $cx[$_-1] eq 'X', 1..$NUM_TREES;
  my @idx = 1..$NUM_TREES;
  my @exist = grep $cx[$_] ne 'X', 0..$#cx;
  @cx  = @cx[@exist];
  @idx = @idx[@exist];

  if (@cx == 1) {
    # Only one symlink left, no message.
  } elsif ($c !~ /[^OX]/) {
    # Symlinks are identical.
    for my $i (0..$#idx) {
      print $OUT "d$idx[$i]/$c.sym: symlinks are identical.\n";
    }
  } else {
    # Symlinks differ.
    my %match;
    for my $i (0..$#cx) {
      push @{ $match{$cx[$i]} }, $i+1;
    }
    for my $i (0..$#cx) {
      my $here = $cx[$i];
      my @other = grep $_ != $i+1, @{ $match{$here} };
      my $eq = '';
      $eq = ' == ' . join ',', @other if @other;
      print $OUT "d$idx[$i]/$c.sym: symlink to 'test_$here'.\n";
    }
  }
}

# Run tree-diff itself

my $td = dirname($0) . "/../tree-diff";
system "$^X '$td' -s d? >actual.out 2>&1";

# Compare the results

system "diff -U0 -w expected.out actual.out > DIFFS";
if ( ! -e "DIFFS" ) {
  die "missing diff output";
} elsif ( -s "DIFFS" ) {
  system "less DIFFS";
} else {
  print "Congratulations, output matches expected.\n";
}
