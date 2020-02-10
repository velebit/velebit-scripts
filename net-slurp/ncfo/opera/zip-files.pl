#!/usr/bin/perl -CSDA
use warnings;
use strict;
use open ':std', ':encoding(UTF-8)';
use Encode ();
use Text::Unidecode;
use POSIX qw( strftime );

my ($year, $short) = split ' ', `./canonicalize-filenames.pl -ps`;
my $prefix = $short . '_';

-d '../zip' or mkdir '../zip' or die "mkdir(../zip): $!";
-d '../zip/links' or mkdir '../zip/links' or die "mkdir(../zip/links): $!";
chdir '../zip/links' || die "chdir(../zip/links): $!";

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

sub concat ( @ );
sub concat ( @ ) {
  @_ or return '';
  my ($first, @rest) = @_;
  my @crest = concat @rest;
  my @concat;
  $first = [ $first ] unless ref $first;
  for my $f (@$first) {
    push @concat, map $f . $_, @crest;
  }
  @concat;
}

sub unused_suffix ( @ ) {
  my (@parts) = @_;
  my $ext = pop @parts;
  for my $suffix ('', 'a'..'z', 'aa'..'zz') {
    my @files = concat @parts, $suffix, $ext;
    grep -e $_, @files or return $suffix;
  }
  die;
}

for my $link (links_in '.') {
  unlink $link or die "unlink($link): $!";
}

my (@working_dirs, @changing_dirs);

for my $subdir ('../pretty', '../people') {
  for my $src (sort { $a cmp $b } subdirs_in $subdir) {
    my $dst = unidecode $src;
    if ($subdir =~ /people/) {
      $dst =~ s/[^-\w]+/_/g;
    } else {
      $dst =~ s/\W+/_/g;  # historical
      $dst = $prefix . $dst;
    }
    symlink "$subdir/$src", $dst or die "symlink($subdir/$src, $dst): $!";
    push @working_dirs, $dst;
  }
}

-d '../LATEST' or mkdir '../LATEST' or die "mkdir(../LATEST): $!";
-d '../out' or mkdir '../out' or die "mkdir(../out): $!";

for my $dir (@working_dirs) {
  my $is_same;
  if (! -d "../LATEST/$dir") {
    $is_same = 0;
  } else {
    my $qdir = $dir;  $qdir =~ s,','\\'',g;
    my $cmd = "diff -q '$qdir/.' '../LATEST/$qdir' >/dev/null 2>&1";
    my $ret = system $cmd;
    $ret == -1 and die "system($cmd): $!";
    $ret & 0x7F and die "system($cmd): died with signal @{[$ret & 0x7F]}";
    $is_same = ($ret == 0);
  }

  warn("--- $dir: unchanged.\n"), next if $is_same;

  push @changing_dirs, $dir;
}

if (@changing_dirs) {
  my $date = strftime('%Y-%m-%d', localtime);

  # If needed, add a suffix to make file names unique.
  # The suffix is generated by considering all files, even if not changing.
  my @out_dirs = ('../out/', '../out/OLD/');
  my $suffix = unused_suffix \@out_dirs, \@working_dirs, '_' . $date, '.zip';

  for my $dir (@changing_dirs) {
    my $zip = '../out/' . $dir . '_' . $date . $suffix . '.zip';
    -e $zip and die "$zip: file already exists!\n";
    warn("*** $zip\n");

    if (-d "../LATEST/$dir") {
      system 'rm', '-rf', "../LATEST/$dir"
	and die "rm -rf '../LATEST/$dir': failed $?";
    }
    system 'cp', '-drp', "$dir/.", "../LATEST/$dir"
      and die "cp -drp '$dir/.' '../LATEST/$dir': failed $?";

    for my $old_zip (glob '../out/' . $dir . '_*.zip') {
      my $dest = $old_zip;
      $dest =~ s,^\.\./out/,../out/OLD/, or die;
      rename $old_zip, $dest or warn "rename($old_zip, $dest): $!, continuing";
    }

    system 'zip', '-qr', $zip, $dir
      and die "zip -qr '$zip' '$dir': failed $?";
  }
}
