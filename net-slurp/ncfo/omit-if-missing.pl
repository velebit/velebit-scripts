#!/usr/bin/perl
use warnings;
use strict;
use open ':std', ':encoding(UTF-8)';

sub is_missing ( $ ) {
  my ($in) = @_;
  -f $in and return 0;
  warn("Input file '$in' is missing!");
  1;
}

my @output;
while (<>) {
  chomp;
  my ($in, $out) = split /=/, $_, 2;
  defined $out or die "bad input format: '$_'";

  push @output, "$_\n" unless is_missing $in;  # print all at the very end
}

print $_ for @output;
