#!/usr/bin/perl
use warnings;
use strict;
use open ':std', ':encoding(UTF-8)';

use Getopt::Long;
use File::Basename qw( dirname );

# ----------------------------------------------------------------------

open my $OUTPUT, '>&', \*STDOUT or die "Cannot dup STDOUT: $!";
open my $MESSAGES, '>&', \*STDERR or die "Cannot dup STDERR: $!";
open STDERR, '>&', $MESSAGES or die "Cannot dup STDERR to STDERR: $!";
open STDOUT, '>&', $MESSAGES or die "Cannot dup STDERR to STDOUT: $!";

our $QUIET;
our $DIR_PATH;
our $DIR_NAME;

our @EYED3_ARGS = ('--to-v2.3');

# ----------------------------------------------------------------------

sub create_dir ( $ );
sub create_dir ( $ ) {
  my ($path) = @_;
  -d $path and return;
  create_dir dirname $path;
  mkdir $path or warn "mkdir($path): $!";
}

sub fixed_gain_name ( $ ) {
  my ($path) = @_;
  my @path = split m!/+!, $path;
  defined $DIR_PATH
    and return join '/', $DIR_PATH, $path[-1];
  my @prefix;
  push @prefix, shift @path while @path and $path[0] =~ /^\.+$/;
  my $dir = shift @path;
  if (defined $DIR_NAME) {
    $dir = $DIR_NAME;
    # A final // means keep the subdirectory path
    @path = ($path[-1]) if ! ($dir =~ s!/{2,}$!!) and @path;
    $dir =~ s!/$!!;
  } else {
    $dir = 'mp3' unless defined $dir;
    $dir .= '-gain';
  }
  join '/', @prefix, $dir, @path;
}

sub fixed_gain ( $ ) {
  my ($in) = @_;
  my ($out) = fixed_gain_name $in;
  my ($t_in) = (stat $in)[9];
  if (! defined $t_in) {
      -f $in or warn("Input file '$in' is missing!"), return undef;
      warn("Input file modtime not found for '$in'"), return $in;
  }
  my ($t_out) = (stat $out)[9];
  if (!defined($t_out) || ($t_out < $t_in)) {
    print STDERR "$out: updating gain.\n";
    create_dir dirname $out;
    -f $out and (unlink $out or warn "unlink($out): $!");
    system('cp', '--', $in, $out) and warn "cp failed.\n";
    open STDOUT, '>', '/dev/null' or die "Cannot dup null to STDOUT: $!"
	if $QUIET;
    open STDERR, '>', '/dev/null' or die "Cannot dup null to STDERR: $!"
	if $QUIET;
    -f $out and system('eyeD3', '-Q', @EYED3_ARGS, $out);
    open STDERR, '>&', $MESSAGES or die "Cannot dup STDERR to STDERR: $!";
    # "Legacy" ID3 tags make eyeD3 --to-v2.3 choke later, so don't use them.
    -f $out and (system('replaygain', '--mp3-format', 'replaygain.org', $out)
		 and print $MESSAGES "replaygain ($out) failed.\n");
    open STDOUT, '>&', $MESSAGES or die "Cannot dup STDERR to STDOUT: $!";
    -f $out and (system('touch', '-r', $in, $out)
		 and print $MESSAGES "Updating timestamp ($out) failed.\n");
  } else {
    print STDERR "$out: keeping.\n" unless $QUIET;
  }
  $out;
}

# ----------------------------------------------------------------------

GetOptions('quiet|q!' => \$QUIET,
	   'wipe|w' => sub {
	       # Specify an empty title because replaygain wants an ID3 header.
	       @EYED3_ARGS = ('--remove-all', '-t', '', '--to-v2.3'); },
	   'output-path|path|p=s' => \$DIR_PATH,
	   'output-directory-name|d=s' => \$DIR_NAME,
	  ) or die("Usage: $0 [-q] [-w] [-p PATH] [-d DIRNAME[//]]" .
		   " [files...]\n");


my @output;
while (<>) {
  chomp;
  my ($in, $out) = split /=/, $_, 2;
  defined $out or die "bad input format: '$_'";

  my $fixed = fixed_gain $in;
  push @output, "$fixed=$out\n" if $fixed;  # print all at the very end
}

print $OUTPUT $_ for @output;
