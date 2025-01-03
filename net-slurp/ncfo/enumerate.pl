#!/usr/bin/perl
use warnings;
use strict;
use open ':std', ':encoding(UTF-8)';
use Getopt::Long;

our $KEEP_EXISTING = 0;
GetOptions('keep-existing|k!' => \$KEEP_EXISTING,
          ) or die "Usage: $0 [--keep-existing] [INPUTS]\n";

sub dir_and_file ( $ ) {
  my ($path) = @_;
  my ($dir, $file) = ($path =~ m,^(.*/)([^/]+)$,)
    or return ('./', $path);
  return ($dir, $file);
}

sub dir_and_num_and_file ( $ ) {
  my ($path) = @_;
  my ($dir, $file) = dir_and_file($path);
  my ($num, $ufile) = ($file =~ m,^(\d+)(.*?)$,)
    or return ($dir, undef, $file);
  return ($dir, $num, $ufile);
}

our %unnumbered;
our %entries;

while (<>) {
  chomp;
  my ($src, $dst) = /^([^=]+)=([^=]+)$/
    or warn("Failed to parse line: '$_'"), next;
  my ($dst_dir, $dst_num, $dst_file) = dir_and_num_and_file $dst;
  push @{$entries{$dst_dir}}, [$src, $dst_dir, $dst_num, $dst_file];
}

for my $dst_dir_key (keys %entries) {
  my $all_numbered = (scalar(grep !defined, map $_->[2],
                             @{$entries{$dst_dir_key}}) == 0);
  my $add_numbers = not ($KEEP_EXISTING and $all_numbered);
  if ($add_numbers) {
    for my $i (0..$#{$entries{$dst_dir_key}}) {
      my $entry = $entries{$dst_dir_key}[$i];
      $entry->[3] = ' ' . join('', grep(defined, $entry->[2], $entry->[3]));
      $entry->[2] = ($i+1);
    }
  }
  for my $entry (@{$entries{$dst_dir_key}}) {
    my ($src, $dst_dir, $dst_num, $dst_file) = @$entry;
    printf "%s=%s%02d%s\n", $src, $dst_dir, $dst_num, $dst_file;
  }
}
