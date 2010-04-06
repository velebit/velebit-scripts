#!/usr/bin/perl
# -*- cperl -*-
# $Id$
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
  --listing     (-l)  Print only file names (relative to the root).
  --identical   (-s)  Report identical files.

  --exclude PAT (-x)  Do not include files matching PAT.
  --xdev              Do not cross device boundaries.

  --check-dev         Check for special device files, and if
                      encountered, compare the device numbers.
                      (This is the default on UNIXish systems.)
  --no-check-dev      Do not check for special device files.
                      (This is the default on Windowsish systems.)
  --no-check-size     Do not check the file size first.
  --no-check-mode     Do not check the file/directory mode.
  --no-check-owner    Do not check the file/directory ownership (UID or GID).
  --no-check-nlinks   Do not check the file/directory hard link count.

  --debug       (-d)  Enable debugging output.
EndOfUsage
  exit 0;
}

use vars qw( $DEBUG $LIST $IDENT @EXCLUDE $ONE_DEVICE );
our $CHECK_FOR_DEVICES = 1 unless $^O eq 'MSWin32' or $^O eq 'cygwin';
our $CHECK_SIZE_BEFORE_CONTENTS = 1;
our $CHECK_MODE = 1;
our $CHECK_OWNERSHIP = 1;
our $CHECK_NLINKS = 1;

Getopt::Long::Configure qw( bundling );
GetOptions('help|h|?'           => \&Usage,
	   'debug|d+'           => \$DEBUG,
           'listing|l!'         => \$LIST,
           'identical|s!'       => \$IDENT,
           'exclude|x=s'        => \@EXCLUDE,
           'xdev!'              => \$ONE_DEVICE,
           'check-dev|dev!'     => \$CHECK_FOR_DEVICES,
           'check-size|size!'   => \$CHECK_SIZE_BEFORE_CONTENTS,
           'check-mode|mode!'   => \$CHECK_MODE,
           'check-owner|owner!' => \$CHECK_OWNERSHIP,
           'check-nlinks|nlinks!' => \$CHECK_NLINKS,
          ) or Usage;

@ARGV >= 2 or Usage;

# Convert the exclude list into regexps.
my %glob2re = ( '?' => '.', '*' => '.*' );
s/(?:(\\.)|(.))/ $1 || $glob2re{$2} || quotemeta($2) /ges, $_ = qr/^$_$/
  for @EXCLUDE;

### code helpers: generic list folding operations

sub uniq_by_count ( @ ) {
  my (@list) = @_;
  return unless @list;
  my %count;
  ++$count{$_} for @list;
  sort { $count{$b} <=> $count{$a} } keys %count;
}

sub most_common ( @ ) {
  my (@list) = @_;
  return unless @list;
  my %count;
  ++$count{$_} for @list;
  my @mcl = sort { $count{$b} <=> $count{$a} } keys %count;
  return $mcl[0] if (@mcl == 1) || ($count{$mcl[0]} != $count{$mcl[1]});
  return;
}

sub is_only_one ( @ ) {
  my (@list) = @_;
  my @uniq = uniq_by_count(@list);
  @uniq == 1;
}

### code helpers: UNIX file modes and devices

sub file_type ( $ ) {
  my ($type) = @_;
  $type = $type & S_IFMT;
  $type == S_IFDIR  and return 'a directory';
  $type == S_IFCHR  and return 'a character device';
  $type == S_IFBLK  and return 'a block device';
  $type == S_IFREG  and return 'a file';
  $type == S_IFLNK  and return 'a symlink';
  $type == S_IFSOCK and return 'a socket';
  $type == S_IFIFO  and return 'a fifo';
  sprintf "an entry of unknown type (octal 0%o)", $type;
}

sub file_rdev ( $ ) {
  my ($rdev) = @_;
  my ($bits);
  $^O eq 'solaris' and $bits = 18;
  $^O eq 'linux'   and $bits = 8;
  $bits and return sprintf("device %d,%d",
                           ($rdev >> $bits), ($rdev & ((1<<$bits) - 1)) );
  sprintf "device 0x%x", $rdev;
}

### common messages

sub dbg_comparing ( $$$@ ) {
  my ($level, $type, $rpath, @info) = @_;
  print STDERR (":> comparing ${type}:\n",
                map ":>   $_->{iroot}$rpath\n", @info)
      if $DEBUG and $DEBUG >= $level;
}

my $msg_differ_list_last = '';

sub msg_differ ( $$$@ ) {
  my ($info, $rpath, $fmt, @args) = @_;
  if ($LIST) {
    $rpath ne $msg_differ_list_last
      and $msg_differ_list_last = $rpath,
        print($rpath . "\n");
  } else {
    print sprintf "%s%s: ${fmt}.\n", $info->{iroot}, $rpath, @args;
  }
}

### differencing code

sub tdiff_entries ( $$@ );
sub tdiff_type_entries ( $$@ );
sub tdiff_files ( $$@ );
sub tdiff_directories ( $$@ );
sub tdiff_symlinks ( $$@ );

sub tdiff_entries ( $$@ ) {
  my ($flags, $rpath, @info) = @_;
  # make a local deep copy so we can modify:
  @info = map +{ %$_ }, @info;

  ## stat the data
  $_->{stat} = File::stat::lstat($_->{root} . $rpath) foreach @info;
  my @stat  = map $_->{stat}, @info;

  my @valid;
  for my $i (0..$#info) {
    $stat[$i] or msg_differ($info[$i], $rpath, "does not exist"), next;
    push @valid, $i;
  }
  return if @valid < 2;

  @info  = @info[@valid];
  @stat  = @stat[@valid];

  ## check for device boundaries
  if (grep exists $_->{xdev}, @info) {
    @valid = ();
    for my $i (0..$#info) {
      $stat[$i]->dev == $info[$i]{xdev}
        or ($DEBUG and msg_differ($info[$i], $rpath, "the device has changed")),
          next;
      push @valid, $i;
    }
    return if @valid < 2;

    @info  = @info[@valid];
    @stat  = @stat[@valid];

  } elsif ($ONE_DEVICE) {
    $info[$_]{xdev} = $stat[$_]->dev for 0..$#info;
    if ($DEBUG) {
      msg_differ($info[$_], $rpath, "device is 0x%x", $info[$_]{xdev})
        for 0..$#info;
    }
  }

  ## segregate by file type
  my @types = map $_->mode & S_IFMT, @stat;
  my @uniq_types = uniq_by_count @types;
  if (@uniq_types > 1) {
    msg_differ($info[$_], $rpath, "is @{[file_type $types[$_]]}") for 0..$#info;
  }

  for my $utype (@uniq_types) {
    @valid = grep $types[$_] == $utype, 0..$#info;
    tdiff_type_entries $flags, $rpath, @info[@valid] if @valid > 1;
  }
}

sub tdiff_type_entries ( $$@ ) {
  my ($flags, $rpath, @info) = @_;
  # Called with a list of entries that have the same file type.
  return if @info < 2;

  # tdiff_entries already made a deep copy and stat'ed the data.
  my @stat  = map $_->{stat}, @info;

  my @valid;

  ## check file device numbers
  if ($CHECK_FOR_DEVICES) {
    my @rdevs = map $_->rdev, @stat;
    if (! is_only_one @rdevs) {
      msg_differ($info[$_], $rpath, "is @{[file_rdev $rdevs[$_]]}")
        for 0..$#info;
    }
  }

  ## check file permissions
  if ($CHECK_MODE) {
    my @modes = map $_->mode & ~S_IFMT, @stat;
    if (! is_only_one @modes) {
      msg_differ($info[$_], $rpath, "is mode 0%o", $modes[$_])
        for 0..$#info;
    }
  }

  ## check file ownership
  if ($CHECK_OWNERSHIP) {
    my @uidgids = map $_->uid . '/' . $_->gid, @stat;
    if (! is_only_one @uidgids) {
      msg_differ($info[$_], $rpath, "is owned by %s", $uidgids[$_])
        for 0..$#info;
    }
  }

  # all entries have to be the same type (all directories, all symlinks, etc)
  my $type = $stat[0]->mode & S_IFMT;

  ## check number of hard links
  if ($CHECK_NLINKS and $type != S_IFDIR) {
    my @nlinks = map $_->nlink, @stat;
    if (! is_only_one @nlinks) {
      msg_differ($info[$_], $rpath, "%d hard links", $nlinks[$_])
        for 0..$#info;
    }
  }

  ## dispatch according to type
  $type == S_IFDIR  and return tdiff_directories $flags, $rpath, @info;
  $type == S_IFREG  and return tdiff_files       $flags, $rpath, @info;
  $type == S_IFLNK  and return tdiff_symlinks    $flags, $rpath, @info;
}

sub tdiff_directories ( $$@ ) {
  my ($flags, $rpath, @info) = @_;
  dbg_comparing 2, 'directories', $rpath, @info;

  my %entries;
 DIR:
  for my $info (@info) {
    opendir my $DIR, $info->{root} . $rpath
      or warn("opendir($info->{root}$rpath): $!"), next DIR;
    /^\.\.?$/ or ++$entries{$_} foreach readdir $DIR;
    closedir $DIR;
  }

  $rpath =~ s!(?<=.)/*$!/!;
  for my $ent (sort keys %entries) {
    my $rpath_ent = $rpath . $ent;
    grep($ent =~ $_, @EXCLUDE)       and next;
    grep($rpath_ent =~ $_, @EXCLUDE) and next;
    tdiff_entries $flags, $rpath_ent, @info;
  }
}

sub tdiff_symlinks ( $$@ ) {
  my ($flags, $rpath, @info) = @_;
  dbg_comparing 3, 'symlinks', $rpath, @info;

  my @links = map readlink($_->{root} . $rpath), @info;

  if (! is_only_one @links) {
    msg_differ($info[$_], $rpath, "symlink to '%s'", $links[$_])
      for 0..$#info;
  } elsif ($IDENT) {
    msg_differ($info[$_], $rpath, 'symlinks are identical')
      for 0..$#info;
  }
}

use constant FILE_READ_LEN => 1024*1024;  # 1MB

sub tdiff_files ( $$@ ) {
  my ($flags, $rpath, @info) = @_;
  dbg_comparing 3, 'plain files', $rpath, @info;

  $info[$_]->{index} = 1+$_ for 0..$#info;
  $_->{handle} = IO::File->new($_->{root} . $rpath, '<'),
    $_->{handle}->binmode(1) foreach @info;
  my $all_equal = 1;

  my (@info_groups, @done_groups);
  if ($CHECK_SIZE_BEFORE_CONTENTS) {
    my @sizes = uniq_by_count map $_->{stat}->size, @info;
    if (@sizes > 1) {
      msg_differ($info[$_], $rpath, "size is %d bytes", $info[$_]{stat}->size)
        for 0..$#info;
      return;
    }

    for my $usize (@sizes) {
      push @info_groups, [ grep $_->{stat}->size == $usize, @info ];
    }
  } else {
    @info_groups = [ @info ];
  }

  my @buffers = ();
 INFO_GROUP:
  while (@info_groups) {
    my $group   = shift @info_groups;
    my @group   = @$group;
    my @buffers = map 'ok::', @group;
    @group < 2 and push(@done_groups, $group), next INFO_GROUP;

  BLOCKS:
    while (1) {
      # Read the next block from all handles in this group.
      # On a successful read, $buffers[$i] will contain 'ok::'
      # followed by the block of data from the file.
    FILE:
      for my $i (0..$#group) {
        my $ret = $group[$i]{handle}->read($buffers[$i], FILE_READ_LEN, 4);
        $ret and length($buffers[$i]) != $ret+4
          and die "internal error: mismatch @{[length($buffers[$i]), $ret]}";
        $ret and next FILE;

        # encountered EOF or error
        $group[$i]{handle} = undef;
        defined $ret
          or msg_differ($info[$i], $rpath, "read error: $!"),
            $buffers[$i] = 'ERR', next FILE;
        $buffers[$i] = 'eof';
      }

      # compare results (including status)
      my @uniq_buf = uniq_by_count @buffers;
      @uniq_buf == 1 and $uniq_buf[0] eq 'eof' and last BLOCKS;
      @uniq_buf == 1 and $uniq_buf[0] ne 'ERR' and next BLOCKS;

      # Have either errors or a mismatch.

      my @new_groups;
      for my $ubuf (@uniq_buf) {
        my @matches = grep $buffers[$_] eq $ubuf, 0..$#info;
        # if error, split them up: don't assume they match one another.
        $ubuf eq 'ERR'
          and push(@done_groups, map [$_], @group[@matches]), next INFO_GROUP;
        # if EOF, these are done.
        $ubuf eq 'eof'
          and push(@done_groups, [ @group[@matches] ]), next INFO_GROUP;
        push @new_groups, [ @group[@matches] ];
      }
      unshift @info_groups, @new_groups;
      next INFO_GROUP;
    }

    # At this point, this whole group did match.
    push @done_groups, $group;
  }

  # Generate the output.
  if (@done_groups == 1) {
    if ($IDENT) {
      msg_differ($info[$_], $rpath, 'files are identical')
        for 0..$#info;
    }
  } else {
    # Go group by group and figure out what matches what.
    for my $dg (@done_groups) {
      my @group = @$dg;
      @group > 1 or next;
      my @indices = sort {$a <=> $b} map $_->{index}, @group;
      for my $elt (@group) {
        my $idx = $elt->{index};
        $elt->{match_text} = sprintf "#$idx == " .
          join ',', grep $_ != $idx, @indices;
      }
    }
    # Now go in order and print out the results
    if (@info > 2) {
      msg_differ($info[$_], $rpath, "files differ (%s)",
                 ($info[$_]{match_text} || ("#" . $info[$_]{index})))
        for 0..$#info;
    } else {
      msg_differ($info[$_], $rpath, "files differ") for 0..$#info;
    }
  }
}

### do it!

select STDERR;
$| = 1;
select STDOUT;
$| = 1;

my $rpath = '';
my @info = map +{ root => $_ }, @ARGV;

# force directory names to end with a /
-d $_->{root} and $_->{root} =~ s!/*$!/! foreach @info;

# indent path names with spaces so they line up
my $width = (sort {$b <=> $a} map length $_->{root}, @info)[0];
$_->{indent} = (' ' x ($width - length $_->{root})) foreach @info;
$_->{iroot} = $_->{indent} . $_->{root}             foreach @info;

tdiff_entries { print_delta => 1 }, $rpath, @info;;
