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
  my ($url, @tags) = split /\t/, $_;
  my %tags = map +($_->[0] => (defined $_->[1] ? $_->[1] : 1)),
    map [split /:/, $_, 2], @tags;
  my $file = $url;
  $file =~ s,.*/,,;
  $file =~ s,\%([0-9A-E]{2}),chr(hex($1)),eig;
  my $dir = $ARGV;
  $dir =~ s,.*/,,;
  $dir =~ s,\..*,,;
  my ($dst_base, $ext) = ($file =~ /^(.*?)((?:\.[^.]*)?)$/);
  exists $tags{out_file} and $dst_base = $tags{out_file};
  exists $tags{out_file_prefix} and $dst_base .= $tags{out_file_prefix};
  exists $tags{out_file_suffix} and $dst_base .= $tags{out_file_suffix};
  $dst_base =~ s,[_/]+,_,g;
  print "$SRC_PREFIX$file=$DST_PREFIX$dir/$dst_base$ext\n";
}
