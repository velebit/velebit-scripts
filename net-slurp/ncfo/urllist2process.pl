#!/usr/bin/perl
use warnings;
use strict;
use Getopt::Long;

our $SRC_PREFIX = 'mp3/';
our $DST_PREFIX = '../';
our $ENUMERATE = 0;
GetOptions('source-prefix|s=s' => \$SRC_PREFIX,
	   'destination-prefix|d=s' => \$DST_PREFIX,
	   'enumerate|n!' => \$ENUMERATE,
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
  exists $tags{out_file_prefix}
    and $dst_base = $tags{out_file_prefix} . $dst_base;
  exists $tags{out_file_suffix} and $dst_base .= $tags{out_file_suffix};
  $ENUMERATE and $dst_base = sprintf("%02d ", $.) . $dst_base;
  $dst_base =~ s,[_/]+,_,g;
  print "$SRC_PREFIX$file=$DST_PREFIX$dir/$dst_base$ext\n";
} continue {
  close ARGV if eof;  # make $. count each file separately
}
