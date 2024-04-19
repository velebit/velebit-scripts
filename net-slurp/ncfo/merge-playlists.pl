#!/usr/bin/perl
use warnings;
use strict;
use open ':std', ':encoding(UTF-8)';
use Getopt::Long;

our $KEEP_DUPLICATES = 0;
GetOptions('keep-duplicates|k!' => \$KEEP_DUPLICATES,
	  ) or die "Usage: $0 [-k] [files...]\n";

my @lists;
my (@tracks, %saw_track);

while (<>) {
  if (/\<media src=\"(.*?)\"/) {
    my ($line, $track) = ($_, $1);
    $track =~ s,^.*[/\\],,;
    push @tracks, $line if $KEEP_DUPLICATES or ! $saw_track{$track};
    ++$saw_track{$track};
  } elsif (/\<title\>(.*?)\</) {
    my ($title) = $1;
    $title =~ s/^\s+//;  $title =~ s/\s+$//;  $title =~ s/\s+/ /;
    $title =~ s/ practice$//;
    push @lists, $title unless grep $_ eq $title, @lists;
  }
}

my $title = join '+', @lists;
$title .= ' ' if length $title;
$title .= 'practice';

print "<?wpl version=\"1.0\"?>\r\n";
print "<smil>\r\n";
print "  <head><title>$title</title></head>\r\n";
print "  <body><seq>\r\n";

print for @tracks;

print "  </seq></body>\r\n";
print "</smil>\r\n";
