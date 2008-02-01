#!/usr/bin/perl
use warnings;
use strict;
use Getopt::Long;

use File::stat ();
use Fcntl qw(:mode);
use IO::File;

### handle command line

sub Usage () {
  print STDERR <<'EndOfUsage';
Usage: $0 [flags] dir1 dir2
Flags:
  --identical  (-s)  Report identical files.
  --xdev       (-x)  Do not cross device boundaries.

  --debug      (-d)  Enable debugging output.
EndOfUsage
  exit 0;
}

use vars qw( $DEBUG $IDENT $ONE_DEVICE );

GetOptions('debug|d!'     => \$DEBUG,
           'identical|s!' => \$IDENT,
           'xdev|x!'      => \$ONE_DEVICE,
          ) or Usage;

@ARGV >= 2 or Usage;

### code helpers

sub uniq_by_count ( @ ) {
  my (@list) = @_;
  my %count;
  ++$count{$_} for @list;
  sort { $count{$b} <=> $count{$a} } keys %count;
}

sub most_common ( @ ) {
  my (@list) = @_;
  return unless @list;
  my $mc = (uniq_by_count @list)[0];
  return unless grep($_ eq $mc, @list) > 1;
  $mc;
}

sub filetype ( $ ) {
  my ($type) = @_;
  $type = $type & S_IFMT;
  $type == S_IFDIR  and return 'a directory';
  $type == S_IFCHR  and return 'a character device';
  $type == S_IFBLK  and return 'a block device';
  $type == S_IFREG  and return 'a file';
  $type == S_IFLNK  and return 'a symlink';
  $type == S_IFSOCK and return 'a socket';
  $type == S_IFIFO  and return 'a fifo';
  return sprintf "of unknown type (octal 0%o)", $type;
}

### differencing code

sub tdiff_files ( $@ );
sub tdiff_directories ( $@ );
sub tdiff_symlinks ( $@ );

sub tdiff_entries ( $@ ) {
  my ($meta, @entries) = @_;
  my @xdev = @{ $meta->{xdev} } if exists $meta->{xdev};

  my @stat = map File::stat::lstat($_) || undef, @entries;

  my @valid;
  for my $i (0..$#entries) {
    $stat[$i] or warn("$entries[$i]: does not exist.\n"), next;
    push @valid, $i;
  }
  return if @valid < 2;

  @entries = @entries[@valid];
  @stat    = @stat[@valid];
  @xdev    = @xdev[@valid] if @xdev;

  if (@xdev) {
    @valid = ();
    for my $i (0..$#entries) {
      $stat[$i]->dev == $xdev[$i]
        or ($DEBUG and warn("$entries[$i]: the device has changed!\n")),
          next;
      push @valid, $i;
    }
    return if @valid < 2;

    @entries = @entries[@valid];
    @stat    = @stat[@valid];
    @xdev    = @xdev[@valid];

  } elsif ($ONE_DEVICE) {
    @xdev = map $_->dev, @stat;
    if ($DEBUG) {
      warn sprintf "%s: device is 0x%x.\n", $entries[$_], $xdev[$_]
        for 0..$#entries;
    }
  }

  my @modes = map $_->mode & ~S_IFMT, @stat;
  my $mode  = most_common @modes;

  my @types = map $_->mode & S_IFMT, @stat;
  my $type  = most_common @types;

  for my $i (0..$#entries) {
    defined $mode
      or warn(sprintf "%s: is mode 0%o.\n", $entries[$i], $modes[$i]), next;
    $modes[$i] == $mode
      or warn(sprintf "%s: is mode 0%o, not 0%o.\n",
              $entries[$i], $modes[$i], $mode), next;
  }

  @valid = ();
  for my $i (0..$#entries) {
    defined $type
      or warn("$entries[$i]: is @{[filetype $types[$i]]}.\n"), next;
    $types[$i] == $type
      or warn("$entries[$i]: is @{[filetype $types[$i]]}, not" .
              " @{[filetype $type]}.\n"), next;
    push @valid, $i;
  }
  return if @valid < 2;

  @entries = @entries[@valid];
  @stat    = @stat[@valid];
  @types   = @types[@valid];

  my %meta = %$meta;
  $meta{xdev} = \@xdev if @xdev;

  $type == S_IFDIR  and return tdiff_directories \%meta, @entries;
  $type == S_IFREG  and return tdiff_files       \%meta, @entries;
  $type == S_IFLNK  and return tdiff_symlinks    \%meta, @entries;
}

sub tdiff_directories ( $@ ) {
  my ($meta, @dirs) = @_;
  s,/*$,/, foreach @dirs;
  my %entries;
 DIR:
  for my $dir (@dirs) {
    opendir my $DIR, $dir or warn("opendir: $!"), next DIR;
    /^\.\.?$/ or ++$entries{$_} foreach readdir $DIR;
    closedir $DIR;
  }

  for my $ent (sort keys %entries) {
    tdiff_entries $meta, map "$_$ent", @dirs;
  }
}

sub tdiff_symlinks ( $@ ) {
  my ($meta, @paths) = @_;
  my @links = map readlink($_), @paths;
  my $link  = most_common @links;

  for my $i (0..$#paths) {
    defined $link
      or warn(sprintf "%s: symlink to '%s'.\n", $paths[$i], $links[$i]), next;
    $links[$i] eq $link
      or warn(sprintf "%s: symlink to '%s', not '%s'.\n",
              $paths[$i], $links[$i], $link), next;
  }
}

use constant FILE_READ_LEN => 1024*1024;

sub tdiff_files ( $@ ) {
  my ($meta, @paths) = @_;
  my @handles = map IO::File->new($_, '<'), @paths;
  my @buffers = map '', @paths;
  my @equal   = map 1, @paths;

  while (grep $_, @handles) {
    # read from all handles
    for my $i (0..$#paths) {
      $handles[$i] or next;
      my $ret = $handles[$i]->read($buffers[$i], FILE_READ_LEN);
      $ret and next;
      $handles[$i] = undef;
      defined $ret
        or warn("$paths[$i]: read error: $!\n"), $equal[$i] = 0, next;
    }

    # compare results
    for my $i (1..$#paths) {
      $handles[$i] or next;
      $buffers[$i] eq $buffers[0]
        or warn(sprintf "%s and %s: files differ.\n",
                $paths[$i], $paths[0]),
                  $handles[$i] = undef, $equal[$i] = 0, next;
    }
  }

  if ($IDENT) {
    for my $i (1..$#paths) {
      $equal[$i]
        and warn(sprintf "%s and %s: files are identical.\n",
                 $paths[$i], $paths[0]);
    }
  }
}

### do it!

tdiff_entries {}, @ARGV;
