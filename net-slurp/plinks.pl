#!/usr/bin/perl
# Show all links in a given page (file).
use warnings;
use strict;

use Getopt::Long;
use HTML::TreeBuilder;

$| = 1;

sub Usage () {
  die "Usage: $0 [-h] [-t] [--table-level LEVEL] FILE\n";
  exit 1;
}

our $SHOW_HEADING = 0;
our $SHOW_TEXT = 0;
our $TABLE_LEVEL;
GetOptions('--show-heading|h!' => \$SHOW_HEADING,
	   '--show-text|t!' => \$SHOW_TEXT,
	   '--table-level|tl=i' => \$TABLE_LEVEL,
	   '--not-in-table' => sub { $TABLE_LEVEL = 0 },
          ) or Usage;
@ARGV == 1 or Usage;


my $tree = HTML::TreeBuilder->new;
$tree->parse_file($ARGV[0]);
$tree->objectify_text();


sub get_text ( $ ) {
  my ($node) = @_;
  $node = $node->clone;
  $node->deobjectify_text();
  my $text = $node->as_text;
  # \xA0 is Latin-1 non-breaking space.
  $text =~ s/[\s\xA0]+/ /sg;
  $text =~ s/^ //;  $text =~ s/ $//;
  $text;
}


sub find_heading ( $ ) {
  my ($node) = @_;
  my (@headings) = $node->look_down(_tag => qr/^(?:h\d|title)$/);
  @headings and return $headings[0];
 SEARCH_LEFT:
  while ($node) {
    if (scalar $node->left) {
      $node = $node->left;
    } else {
      $node = $node->parent;
      redo SEARCH_LEFT;
    }
    @headings = $node->look_down(_tag => qr/^(?:h\d|title)$/);
    @headings and return $headings[-1];
  }
  return;
}


my @pages;
# only look at <a ...> tags
for my $tag ($tree->look_down(_tag => 'a')) {
  my $href = $tag->attr('href')
    or next;
  defined $TABLE_LEVEL
    and scalar(@{[$tag->look_up(_tag => 'table')]}) != $TABLE_LEVEL
      and next;
  my $text = get_text($tag) if $SHOW_TEXT;
  my $heading = find_heading($tag) if $SHOW_HEADING;
  $heading = $heading ? get_text($heading) : '' if $SHOW_HEADING;
  push @pages, { heading => $heading, text => $text, href => $href };
}

my @fields = ( 'href' );
$SHOW_TEXT and unshift @fields, 'text';
$SHOW_HEADING and unshift @fields, 'heading';


print join("\t", @$_{@fields}) . "\n" for @pages;
