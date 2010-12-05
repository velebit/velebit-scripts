#!/usr/bin/perl
# Create Windows Media Player playlists from a MP3 tree.
use warnings;
use strict;
use File::Find;
#use Cwd;

my $script = $0;  $script =~ s,.*[/\\],,;
my $force = 1;

sub write_m3u ( $$@ ) {
  my ($file, $title, @list) = @_;
  open my $FILE, '>', $file or die "open(>$file): $!";
  print $FILE "## generated by $script\n";
  # FIXME: this will write utf8; we need to convert to latin1 ?!?
  print $FILE "$_\n" for @list;
}

sub write_wpl ( $$@ ) {
  my ($file, $title, @list) = @_;
  my $count = scalar @list;
  my $text = <<"EndOfHeader";
<?wpl version="1.0"?>
<smil>
  <head>
    <meta name="Generator" content="$script"/>
    <meta name="ItemCount" content="$count"/>
    <title>$title</title>
  </head>
  <body><seq>
EndOfHeader
  for my $item (@list) {
    $item =~ s,/,\\,g;
    $item =~ s,&,&amp;,g;
    $text .= qq[    <media src="$item"/>\n];
  }
  $text .= <<"EndOfFooter";
  </seq></body>
</smil>
EndOfFooter
  $text =~ s/\r?//g;  $text =~ s/\n/\r\n/g;
  open my $FILE, '>', $file or die "open(>$file): $!";
  print $FILE $text;
}

my (%mp3s, %children);
sub process_mp3s {
  /\.mp3$/ or return;
  -f $_    or return;

  my @dir = split m:/:, $File::Find::name;
  my @file = pop @dir;

  while (@dir) {
    my $dir = join '/', @dir;
    push @{$mp3s{$dir}}, join '/', @file;
    $children{$dir}{$file[0]}++;
    unshift @file, pop @dir;
  }
}

find +{ preprocess => sub { sort @_; }, wanted => \&process_mp3s }, '.';

for my $dir (sort keys %mp3s) {
  my $wpl = "$dir/00_playlist.wpl";

  if (@{$mp3s{$dir}} <= 1 or keys %{$children{$dir}} <= 1) {
    if (! -e $wpl) {
      print "SKIP  $dir\n";
    } elsif (!$force) {
      print "LEAVE $dir\n";
    } else {
      print "rm    $dir\n";
      unlink $wpl or warn "unlink($wpl): $!";
    }
    next;
  }

  if (-e $wpl && !$force) {
    print "KEEP  $dir\n";
  } else {
    print "write $dir\n";
    my $name = $dir;  $name =~ s,^.*/,,;
    write_wpl $wpl, $name, @{$mp3s{$dir}};
  }
}
