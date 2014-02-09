#!/usr/bin/perl
use warnings;
use strict;

use File::Basename qw( dirname );

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
  my @prefix;
  push @prefix, shift @path while @path and $path[0] =~ /^\.+$/;
  my $dir = shift @path;
  $dir = 'mp3' unless defined $dir;
  $dir .= '-gain';
  join '/', @prefix, $dir, @path;
}

sub fixed_gain ( $ ) {
  my ($in) = @_;
  my ($out) = fixed_gain_name $in;
  my ($t_in) = (stat $in)[9];
  defined $t_in or die "Input file modtime not found for '$in'";
  my ($t_out) = (stat $out)[9];
  if (!defined($t_out) || ($t_out < $t_in)) {
    print STDERR "$out: updating gain.\n";
    create_dir dirname $out;
    -f $out and (unlink $out or warn "unlink($out): $!");
    system('cp', '--', $in, $out) and warn "cp failed.\n";
    -f $out and (system('mp3gain', '-r', '-k', '-s', 's', '-q', $out)
		 and warn "mp3gain ($out) failed.\n");
  } else {
    print STDERR "$out: keeping.\n";
  }
  $out;
}

# ----------------------------------------------------------------------

open my $OUTPUT, '>&', \*STDOUT or die "Cannot dup STDOUT: $!";
open STDOUT, '>&', \*STDERR or die "Cannot dup STDERR to STDOUT: $!";

my @output;
while (<>) {
  chomp;
  my ($in, $out) = split /=/, $_, 2;
  defined $out or die "bad input format: '$_'";

  my $fixed = fixed_gain $in;
  push @output, "$fixed=$out\n";  # print all at the very end
}

print $OUTPUT $_ for @output;
