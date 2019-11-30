#!/usr/bin/perl
use warnings;
use strict;
use open ':std', ':encoding(UTF-8)';

sub dir_and_file ( $ ) {
  my ($path) = @_;
  my ($dir, $file) = ($path =~ m,^(.*/)([^/]+)$,)
    or return ('./', $path);
  return ($dir, $file);
}

our %counts;

while (<>) {
  chomp;
  my ($src, $dst) = /^([^=]+)=([^=]+)$/
    or warn("Failed to parse line: '$_'"), next;
  my ($dst_dir, $dst_file) = dir_and_file $dst;
  printf "%s=%s%02d %s\n", $src, $dst_dir, (++$counts{$dst_dir}), $dst_file;
}
