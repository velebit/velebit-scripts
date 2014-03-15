#!/usr/bin/perl
use warnings;
use strict;

use Cwd qw( getcwd );
use File::Spec qw( splitpath catpath splitdir );
use Getopt::Long;

# ----------------------------------------------------------------------

our $PRINT_SHORT_NAME;
GetOptions('print-short-name|short-name|ps!' => \$PRINT_SHORT_NAME,
          ) or die "Usage: $0 [--ps | files...]\n";

# ----------------------------------------------------------------------

my @EXTRA_STRIPPED_PREFIXES = qw( 14P10 );

my @wd_elements = split(m!/!, getcwd);
pop @wd_elements if @wd_elements and $wd_elements[-1] =~ /^download/;
my $short_name = $wd_elements[-1];
$short_name =~ s/[\[\]]+//g;
$short_name =~ s/(?<!\S)(\w[A-Z0-9]*)/[$1]/g;
$short_name =~ s/^/\]/;
$short_name =~ s/$/\[/;
$short_name =~ s/\].*?\[//g;
$short_name =~ /[\[\]]/ and die "bad short name generated: '$short_name'\n ";

if ($PRINT_SHORT_NAME) {
  print "$short_name\n";
  exit 0;
}

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
