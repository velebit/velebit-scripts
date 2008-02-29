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
  --check-dev        Check for special device files, and if
                     encountered, compare the device numbers.
                     (This is the default on UNIXish systems.)
  --no-check-dev     Do not check for special device files.
                     (This is the default on Windowsish systems.)

  --debug      (-d)  Enable debugging output.
EndOfUsage
  exit 0;
}

use vars qw( $DEBUG $IDENT $ONE_DEVICE $CHECK_FOR_DEVICES );
$CHECK_FOR_DEVICES = 1 unless $^O eq 'MSWin32' or $^O eq 'cygwin';

GetOptions('debug|d+'     => \$DEBUG,
           'identical|s!' => \$IDENT,
           'xdev|x!'      => \$ONE_DEVICE,
           'check-dev!'   => \$CHECK_FOR_DEVICES,
          ) or Usage;

@ARGV >= 2 or Usage;

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

sub dbg_comparing ( $$@ ) {
  my ($level, $type, @info) = @_;
  print STDERR (":> comparing ${type}:\n",
                map ":>   $_->{path}\n", @info)
      if $DEBUG and $DEBUG >= $level;
}

### differencing code

sub tdiff_entries ( $@ );
sub tdiff_type_entries ( $@ );
sub tdiff_files ( $@ );
sub tdiff_directories ( $@ );
sub tdiff_symlinks ( $@ );

sub tdiff_entries ( $@ ) {
  my ($flags, @info) = @_;
  # make a local deep copy so we can modify:
  @info = map +{ %$_ }, @info;

  ## stat the data
  $_->{stat} = File::stat::lstat($_->{path}) foreach @info;
  my @stat  = map $_->{stat}, @info;

  my @ipath = map $_->{indent} . $_->{path}, @info;

  my @valid;
  for my $i (0..$#info) {
    $stat[$i] or warn("$ipath[$i]: does not exist.\n"), next;
    push @valid, $i;
  }
  return if @valid < 2;

  @info  = @info[@valid];
  @stat  = @stat[@valid];
  @ipath = @ipath[@valid];

  ## check for device boundaries
  if (grep exists $_->{xdev}, @info) {
    @valid = ();
    for my $i (0..$#info) {
      $stat[$i]->dev == $info[$i]{xdev}
        or ($DEBUG and warn("$ipath[$i]: the device has changed!\n")),
          next;
      push @valid, $i;
    }
    return if @valid < 2;

    @info  = @info[@valid];
    @stat  = @stat[@valid];
    @ipath = @ipath[@valid];

  } elsif ($ONE_DEVICE) {
    $info[$_]{xdev} = $stat[$_]->dev for 0..$#info;
    if ($DEBUG) {
      warn sprintf "%s: device is 0x%x.\n", $ipath[$_], $info[$_]{xdev}
        for 0..$#info;
    }
  }

  ## segregate by file type
  my @types = map $_->mode & S_IFMT, @stat;
  my @uniq_types = uniq_by_count @types;
  if (@uniq_types > 1) {
    warn("$ipath[$_]: is @{[file_type $types[$_]]}.\n") for 0..$#ipath;
  }

  for my $utype (@uniq_types) {
    @valid = grep $types[$_] == $utype, 0..$#info;
    tdiff_type_entries $flags, @info[@valid] if @valid > 1;
  }
}

sub tdiff_type_entries ( $@ ) {
  my ($flags, @info) = @_;
  # Called with a list of entries that have the same file type.
  return if @info < 2;

  # tdiff_entries already made a deep copy and stat'ed the data.
  my @stat  = map $_->{stat}, @info;
  my @ipath = map $_->{indent} . $_->{path}, @info;

  my @valid;

  ## check file device numbers
  if ($CHECK_FOR_DEVICES) {
    my @rdevs = map $_->rdev, @stat;
    if (! is_only_one @rdevs) {
      warn "$ipath[$_]: is @{[file_rdev $rdevs[$_]]}.\n"
        for 0..$#ipath;
    }
  }

  ## check file permissions
  {
    my @modes = map $_->mode & ~S_IFMT, @stat;
    if (! is_only_one @modes) {
      warn sprintf "%s: is mode 0%o.\n", $ipath[$_], $modes[$_]
        for 0..$#ipath;
    }
  }

  ## check file ownership
  {
    my @uidgids = map $_->uid . '/' . $_->gid, @stat;
    if (! is_only_one @uidgids) {
      warn sprintf "%s: is owned by %s.\n", $ipath[$_], $uidgids[$_]
        for 0..$#ipath;
    }
  }

  # all entries have to be the same type (all directories, all symlinks, etc)
  my $type = $stat[0]->mode & S_IFMT;

  ## check number of hard links
  if ($type != S_IFDIR) {
    my @nlinks = map $_->nlink, @stat;
    if (! is_only_one @nlinks) {
      warn sprintf "%s: %d hard links.\n", $ipath[$_], $nlinks[$_]
        for 0..$#ipath;
    }
  }

  ## dispatch according to type
  $type == S_IFDIR  and return tdiff_directories $flags, @info;
  $type == S_IFREG  and return tdiff_files       $flags, @info;
  $type == S_IFLNK  and return tdiff_symlinks    $flags, @info;
}

sub tdiff_directories ( $@ ) {
  my ($flags, @info) = @_;
  dbg_comparing 2, 'directories', @info;

  my %entries;
 DIR:
  for my $info (@info) {
    opendir my $DIR, $info->{path}
      or warn("opendir($info->{path}): $!"), next DIR;
    /^\.\.?$/ or ++$entries{$_} foreach readdir $DIR;
    closedir $DIR;
  }

  for my $ent (sort keys %entries) {
    # make a local deep copy for the loop:
    my @cinfo = map +{ %$_ }, @info;
    $_->{path} =~ s!/*$!/$ent! foreach @cinfo;
    tdiff_entries $flags, @cinfo;
  }
}

sub tdiff_symlinks ( $@ ) {
  my ($flags, @info) = @_;
  dbg_comparing 3, 'symlinks', @info;

  my @links = map readlink($_->{path}), @info;

  if (! is_only_one @links) {
    warn sprintf "%s%s: symlink to '%s'.\n",
      $info[$_]{indent}, $info[$_]{path}, $links[$_]
        for 0..$#info;
  } elsif ($IDENT) {
    warn sprintf "%s%s: symlinks are identical.\n",
      $info[$_]{indent}, $info[$_]{path}
        for 0..$#info;
  }
}

use constant FILE_READ_LEN => 1024*1024;  # 1MB

sub tdiff_files ( $@ ) {
  my ($flags, @info) = @_;
  dbg_comparing 3, 'plain files', @info;

  $info[$_]->{index} = 1+$_ for 0..$#info;
  $_->{handle} = IO::File->new($_->{path}, '<') foreach @info;
  my $all_equal = 1;

  my @sizes = uniq_by_count map $_->{stat}->size, @info;
  if (@sizes > 1) {
    warn sprintf "%s%s: size is %d bytes.\n",
      $info[$_]{indent}, $info[$_]{path}, $info[$_]{stat}->size
        for 0..$#info;
    return;
  }

  my (@info_groups, @done_groups);
  for my $usize (@sizes) {
    push @info_groups, [ grep $_->{stat}->size == $usize, @info ];
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
          or warn("$info[$i]{indent}$info[$i]{path}: read error: $!\n"),
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
      warn sprintf "%s%s: files are identical.\n",
        $info[$_]{indent}, $info[$_]{path}
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
    warn sprintf "%s%s: files differ (%s).\n",
      $info[$_]{indent}, $info[$_]{path},
        ($info[$_]{match_text} || ("#" . $info[$_]{index}))
          for 0..$#info;
  }
}

### do it!

select STDERR;
$| = 1;
select STDOUT;
$| = 1;

my @info = map +{ path => $_ }, @ARGV;

# force directory names to end with a /
-d $_->{path} and $_->{path} =~ s,/*$,/, foreach @info;

# indent path names with spaces so they line up
my $width = (sort {$b <=> $a} map length $_->{path}, @info)[0];
$_->{indent} = (' ' x ($width - length $_->{path})) foreach @info;

tdiff_entries { print_delta => 1 }, @info;;
