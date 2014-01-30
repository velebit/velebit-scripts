#!/usr/bin/perl
use warnings;
use strict;
use Getopt::Long;

our $SRC_PREFIX = 'mp3/';
our $DST_PREFIX = '../';
GetOptions('source-prefix|s=s' => \$SRC_PREFIX,
	   'destination-prefix|d=s' => \$DST_PREFIX,
          ) or die "Usage: $0 [-s SRC/] [-d DST/] [files...]\n";


# ----------------------------------------------------------------------

while (<>) {
  chomp;
  s,.*/,,;
  my $dir = $ARGV;  $dir =~ s,.*/,,;  $dir =~ s,\..*,,;
  print "$SRC_PREFIX$_=$DST_PREFIX$dir/$_\n";
}
