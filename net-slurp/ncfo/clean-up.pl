#!/usr/bin/perl
use warnings;
use strict;
use utf8;
use open ':std', ':encoding(UTF-8)';
use Getopt::Long;

our @IGNORED = ( 'html/' );
our @DIRS = ();
GetOptions('ignore|i=s' => \@IGNORED,
	   'directory|d=s' => \@DIRS,
          ) or die "Usage: $0 [-d DIR] [-i IGNORE] LOG_FILE\n";
@ARGV > 1  and die "Usage: $0 [-d DIR] [-i IGNORE] LOG_FILE\n";

my $log = @ARGV ? shift @ARGV : 'download.log';

my $ignored_re = '(?:^|/)(?:\d+|' . join('|', map "\Q$_", @IGNORED) . ')$';
$ignored_re =~ qr/$ignored_re/;

### Get a list of referenced files from the download log.

my @referenced;
my @added;

open my $LOG, '<', $log or die "open($log): $!";
while (<$LOG>) {
  s/[\r\n]+//g;
  if (/^(?:Saving to: |Server file no newer than local file |File .* not modified on server)/) {
    my ($file) = /[`'‘](.+)['’]/
      or die "Format error: no file name found in\n    $_\n ";
    #print STDERR "F $file\n";
    if ($file !~ $ignored_re) {
      push @referenced, $file;
      push @added, $file if /^Saving to: /;
    }

  } elsif (/^\d{4}-\d{2}-\d{2} /) {
    # Don't complain about `...' in date lines; just skip them.

  } elsif (/[`‘][^`'‘’]*['’]/) {
    warn "Unexpected quoted name seen in\n    $_\n ";
  }
}

my %ref_dir = map +($_ => 1), @DIRS;
m,^(.+)/, and $1 ne '.' and ++$ref_dir{$1} foreach @referenced;
my @ref_dir = sort { $ref_dir{$b} <=> $ref_dir{$a} } keys %ref_dir;

printf "%4d new file(s) were downloaded:\n", scalar @added if @added;
print  "      $_\n" foreach @added;

printf "%4d files referenced during download\n", scalar @referenced;

### Get a list of files actually present in the file system.

my @found = map glob("$_/*"), @ref_dir;

printf "%4d files found on disk in %d directories\n",
  scalar @found, scalar @ref_dir;

### Compare the lists

my (%referenced, %found);
$referenced{$_}++ foreach @referenced;
$found{$_}++      foreach @found;

my @all = sort keys %{ +{ %referenced, %found } };
#printf "%4d files combined\n", scalar @all;

my ($ignored, $rm_ok, $rm_fail, $missing);
for my $f (@all) {
  if ($found{$f} and !$referenced{$f}) {
    if ($f =~ $ignored_re) {
      print("'$f' was ignored.\n");
      ++$ignored;
    } elsif (! unlink $f) {
      warn "remove($f): $!";
      ++$rm_fail;
    } else {
      print "'$f' is old, removed.\n";
      ++$rm_ok;
    }

  } elsif ($referenced{$f} and !$found{$f}) {
    print "'$f' downloaded but not found.\n";
    ++$missing;
  }
}

printf "%4d new files missing\n", $missing if $missing;
printf "%4d old files ignored\n", $ignored if $ignored;
printf "%4d old files removed\n", $rm_ok if $rm_ok;
printf "%4d removals failed\n", $rm_fail if $rm_fail;
print  "Nothing needed to be removed\n" if !($rm_ok || $rm_fail);
