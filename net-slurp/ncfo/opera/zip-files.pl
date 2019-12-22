#!/usr/bin/perl -CSDA
use warnings;
use strict;
use open ':std', ':encoding(UTF-8)';
use Encode ();
use Text::Unidecode;
use POSIX qw( strftime );

my ($year, $short) = split ' ', `./canonicalize-filenames.pl -ps`;
my $prefix = $short . '_';

chdir '../zip' || die "chdir(../zip): $!";

sub dir_entries ( $ ) {
  my ($dir) = @_;
  opendir my $dh, $dir or die "opendir($dir): $!";
  # this is likely ridiculously platform dependent...
  map Encode::decode('utf8', $_), grep !/^\.\.?$/, readdir $dh;
}

sub subdirs_in ( $ ) {
  my ($dir) = @_;
  grep -d "$dir/$_", dir_entries $dir;
}

sub links_in ( $ ) {
  my ($dir) = @_;
  grep -l "$dir/$_", dir_entries $dir;
}

for my $link (links_in '.') {
  unlink $link or die "unlink($link): $!";
}

my (@working_dirs, $date);

for my $src (subdirs_in 'pretty') {
  my $dst = unidecode $src;
  $dst =~ s/\W+/_/g;
  $dst = $prefix . $dst;
  symlink "pretty/$src", $dst or die "symlink(pretty/$src, $dst): $!";
  push @working_dirs, $dst;
}

-d 'LATEST' or mkdir 'LATEST' or die "mkdir(LATEST): $!";
-d 'out' or mkdir 'out' or die "mkdir(out): $!";

for my $dir (@working_dirs) {
  my $is_same;
  if (! -d "LATEST/$dir") {
    $is_same = 0;
  } else {
    my $cmd = "diff -q '\Q$dir\E/.' 'LATEST/\Q$dir\E' >/dev/null 2>&1";
    my $ret = system $cmd;
    $ret == -1 and die "system($cmd): $!";
    $ret & 0x7F and die "system($cmd): died with signal @{[$ret & 0x7F]}";
    $is_same = ($ret == 0);
  }

  warn("--- $dir: unchanged.\n"), next if $is_same;

  $date = strftime('%Y-%m-%d', localtime) unless defined $date;
  my $zip = 'out/' . $dir . '_' . $date . '.zip';
  warn("*** $zip\n");

  if (-d "LATEST/$dir") {
    system 'rm', '-rf', "LATEST/$dir" and die "rm -rf 'LATEST/$dir': failed $?";
  }
  system 'cp', '-drp', "$dir/.", "LATEST/$dir"
    and die "cp -drp '$dir/.' 'LATEST/$dir': failed $?";

  ! -e $zip or unlink $zip or die "unlink($zip): $!";
  system 'zip', '-qr', $zip, $dir and die "zip -qr '$zip' '$dir': failed $?";
}
