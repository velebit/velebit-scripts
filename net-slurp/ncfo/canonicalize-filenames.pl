#!/usr/bin/perl
use warnings;
use strict;

use Cwd qw( getcwd );
use File::Spec qw( splitpath catpath splitdir );

# ----------------------------------------------------------------------

my $short_name = (split(m!/!, getcwd))[-2];
$short_name =~ s/[\[\]]+//g;
$short_name =~ s/(?<!\S)(\w[A-Z0-9]*)/[$1]/g;
$short_name =~ s/^/\]/;
$short_name =~ s/$/\[/;
$short_name =~ s/\].*?\[//g;
$short_name =~ /[\[\]]/ and die "bad short name generated: '$short_name'\n ";

my @EXTRA_STRIPPED_PREFIXES = qw( 14P10 );

# ----------------------------------------------------------------------

sub canonicalize_file ( $ ) {
  my ($file) = @_;
  $file =~ s/\.mp3$//i;
  $file =~ s/^\Q$_\E[-_]// for @EXTRA_STRIPPED_PREFIXES;
  $file =~ s/^[^\.]*?(?=\d)/${short_name}/
    or $file =~ s/practice//i;
  $file =~ s/^(\Q${short_name}\E\d+)[-_](\d+)/$1.$2/;
  #$file =~ s/(\d+)/sprintf "%02d", $1/ge;
  $file . '.mp3';
}

sub canonicalize ( $ ) {
  my ($path) = @_;
  my (@path) = split m!/+!, $path;
  $path[-1] = canonicalize_file $path[-1];
  join '/', @path;
}

# ----------------------------------------------------------------------

my @output;
while (<>) {
  chomp;
  my ($in, $out) = split /=/, $_, 2;
  defined $out or die "bad input format: '$_'";

  my $fixed = canonicalize $out;
  print "$in=$fixed\n";
}
