#!/usr/bin/perl
use warnings;
use strict;
use utf8;
use open ':std', ':encoding(UTF-8)';
use Getopt::Long;
use File::Spec;

our @IGNORED = ( 'html/' );
our @DIRS = ();
our @EXCLUDED_DIRS = ();
our @REFERENCE_FILES = ();
GetOptions('ignore|i=s' => \@IGNORED,
	   'directory|d=s' => \@DIRS,
	   'exclude-directory=s' => \@EXCLUDED_DIRS,
	   'reference-file=s' => \@REFERENCE_FILES,
          ) or die "Usage: $0 [-d DIR] [-i IGNORE] [--exclude-directory DIR] [--reference-file FILE] LOG_FILE\n";
@ARGV > 1  and die "Usage: $0 [-d DIR] [-i IGNORE] [--exclude-directory DIR] [--reference-file FILE] LOG_FILE\n";

my $log = @ARGV ? shift @ARGV : 'download.log';

my $ignored_re = '(?:^|/)(?:\d+|' . join('|', map "\Q$_", @IGNORED) . ')$';
$ignored_re =~ qr/$ignored_re/;

sub is_excluded_directory {
  my ($path) = @_;
  my $absolute_path = File::Spec->canonpath(File::Spec->rel2abs($path));
  for my $directory (@EXCLUDED_DIRS) {
    my $absolute_directory =
      File::Spec->canonpath(File::Spec->rel2abs($directory));
    return 1 if $absolute_path eq $absolute_directory;
    return 1 if index($absolute_path, "$absolute_directory/") == 0;
  }
  return 0;
}

### Get a list of referenced files from the download log.

my @referenced;
my @added;
my %code_counts;
my %code_desc;

my $is_ok_if_file_missing = 0;
open my $LOG, '<', $log or die "open($log): $!";
while (<$LOG>) {
  s/[\r\n]+//g;
  if (/^(?:Saving to: |Server file no newer than local file |File .* not modified on server)/) {
    my ($file) = /[`'‘](.+)['’]/
      or die "Format error: no file name found in\n    $_\n ";
    # Expand `\ooo` sequences in wget output
    $file =~ s/\\(?:(\\)|([0-7]{1,3}))/$1 or chr(oct($2))/ge;
    #print STDERR "F $file\n";
    if ($file !~ $ignored_re && !is_excluded_directory($file)) {
      push @referenced, $file;
      push @added, $file if /^Saving to: /;
    }
    $is_ok_if_file_missing = 0;

  } elsif (/^(?:--)?\d{4}-\d{2}-\d{2} /) {
    # Don't complain about `...' in date lines; just skip them.

    # But mark robot.txt URLs so we know they don't HAVE to exist:
    $is_ok_if_file_missing = (m,/robots\.txt$, ? 1 : 0);

  } elsif (/[`‘]([^`'‘’]*)['’]/) {
    my $file = $1;
    $file =~ s/\\(?:(\\)|([0-7]{1,3}))/$1 or chr(oct($2))/ge;
    warn "Unexpected quoted name seen in\n    $_\n "
      unless is_excluded_directory($file);

  } elsif (/^HTTP request sent.*\.\.\.\s*(\d+)\s*(.*)$/) {
    ++$code_counts{$1} unless $1 eq '404' and $is_ok_if_file_missing;
    $code_desc{$1} = $2;
    $is_ok_if_file_missing = 0;

  } elsif (/^\s*$/) {
    $is_ok_if_file_missing = 0;
  }
}

for my $reference_file (@REFERENCE_FILES) {
  open my $REF, '<', $reference_file
    or die "open($reference_file): $!";
  while (<$REF>) {
    s/[\r\n]+$//;
    my ($kind, $file) = split /\t/, $_, 2;
    defined $file && ($kind eq 'new' || $kind eq 'keep')
      or die "Invalid reference entry in $reference_file:\n    $_\n";
    $file =~ s/\\(?:(\\)|([0-7]{1,3}))/$1 or chr(oct($2))/ge;
    push @referenced, $file;
    push @added, $file if $kind eq 'new';
  }
  close $REF or die "close($reference_file): $!";
}

my %ref_dir = map +($_ => 1), @DIRS;
m,^(.+)/, and $1 ne '.' and ++$ref_dir{$1} foreach @referenced;
my @ref_dir = sort { $ref_dir{$b} <=> $ref_dir{$a} } keys %ref_dir;

if (! %code_counts) {
  print "Warning: no HTTP results were seen in the output!?\n";
} else {
  printf "HTTP: %4d file(s) ***FAILED TO BE RETRIEVED.***\n",
    delete $code_counts{404} if exists $code_counts{404};
  printf "HTTP: %4d file(s) were retrieved.\n",
    delete $code_counts{200} if exists $code_counts{200};
  printf "HTTP: %4d files have stayed the same.\n",
    delete $code_counts{304} if exists $code_counts{304};
  printf "HTTP: %4d files had status: %s %s.\n",
    $code_counts{$_}, $_, $code_desc{$_} foreach keys %code_counts;
}

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
