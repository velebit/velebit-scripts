#!/usr/bin/perl
# Show all links in a given page (file).
use warnings;
use strict;

use HTML::TreeBuilder;

$| = 1;

our $SHOW_TEXT = 0;
while (@ARGV and $ARGV[0] =~ /^-/) {
  $ARGV[0] eq '-t' and ++$SHOW_TEXT, shift(@ARGV), next;
  die "Unknown argument '$ARGV[0]'";
}
@ARGV == 1 or die "Usage: $0 [-t] {FILE}\n";


my $tree = HTML::TreeBuilder->new;
$tree->parse_file($ARGV[0]);

my @pages;
# only look at <a ...> tags
for my $tag ($tree->look_down(_tag => 'a')) {
  my $href = $tag->attr('href')
    or next;
  my $text = $tag->as_text;
  $text =~ s/\s+/ /sg;
  $text =~ s/^ //;  $text =~ s/ $//;
  push @pages, [$text, $href];
}

if ($SHOW_TEXT) {
  print "$_->[0]\t$_->[1]\n" for @pages;
} else {
  print "$_->[1]\n" for @pages;
}
