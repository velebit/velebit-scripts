#!/usr/bin/perl
use warnings;
use strict;

my $log = @ARGV ? shift @ARGV : 'download.log';

### Get a list of referenced files from the download log.

my @referenced;

open my $LOG, '<', $log or die "open($log): $!";
while (<$LOG>) {
  s/[\r\n]+//g;
  if (/^(?:Saving to:|Server file no newer than local file) /) {
    #print ":$_\n";
    my ($file) = /\`([^\`\']+)\'/
      or die "Format error: no file name found in\n    $_\n ";
    #print "F $file\n";
    push @referenced, $file
      unless $file =~ m!(?:^|/)(?:\d+|index\.html)$!;

  } elsif (/^\d{4}-\d{2}-\d{2} /) {
    # Don't complain about `...' in date lines; just skip them.
    #print "\@$_\n";

  } elsif (/\`[^\`\']*\'/) {
    warn "Unexpected quoted name seen in\n    $_\n ";
  }
}

my %ref_dir;
m,^(.+)/, and $1 ne '.' and ++$ref_dir{$1} foreach @referenced;
my @ref_dir = sort { $ref_dir{$b} <=> $ref_dir{$a} } keys %ref_dir;

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

my ($rm_ok, $rm_fail);
for my $f (@all) {
  if ($found{$f} and !$referenced{$f}) {
    if (unlink $f) {
      print "'$f' is old, removed.\n";
    } else {
      warn "remove($f): $!";
    }

  } elsif ($referenced{$f} and !$found{$f}) {
    print "'$f' downloaded but not found.\n";
  }
}

printf "%4d old files removed\n", $rm_ok if $rm_ok;
printf "%4d removals failed\n", $rm_fail if $rm_fail;
print  "Nothing needed to be done\n"     if !($rm_ok || $rm_fail);
