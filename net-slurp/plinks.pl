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
our $SHOW_PARENT1_TEXT = 0;
our $STRONG_IS_HEADING_TOO = 0;
our $TABLE_LEVEL;
GetOptions('--show-heading|h!' => \$SHOW_HEADING,
	   '--bold-is-heading|b' =>
	   sub { $STRONG_IS_HEADING_TOO = 1;  $SHOW_HEADING = 1 },
	   '--show-text|t!' => \$SHOW_TEXT,
	   '--show-parent-text|pt!' => \$SHOW_PARENT1_TEXT,
	   '--table-level|tl=i' => \$TABLE_LEVEL,
	   '--not-in-table' => sub { $TABLE_LEVEL = 0 },
          ) or Usage;
@ARGV == 1 or Usage;


my $tree = HTML::TreeBuilder->new;
$tree->parse_file($ARGV[0]);
$tree->objectify_text();


sub get_text ( $ ) {
  my ($node) = @_;
  return '' unless $node;
  $node = $node->clone;
  $node->deobjectify_text();
  my $text = $node->as_text;
  # 0xA0 is a non-breaking space in Latin-1 and Unicode.
  # 0xC2 0xA0 is the UTF-8 representation of U+00A0; this is a horrible hack.
  $text =~ s/[\s\xA0\xC2]+/ /sg;
  $text =~ s/^ //;  $text =~ s/ $//;
  $text;
}


sub nonempty ( @ ) {
  grep(($_->tag ne '~text' or $_->attr('text') !~ /^[\s\xA0]+$/s), @_);
}


sub get_headings ( $ ) {
  my ($node) = @_;
  return unless $node;
  return $node->look_down(_tag => qr/^(?:h\d|title)$/)
    unless $STRONG_IS_HEADING_TOO;
  grep(($_->tag ne 'strong'
	or ($_->parent->tag =~ /^(?:p|dt)$/
	    and nonempty($_->parent->content_list) == 1)),
       $node->look_down(_tag => qr/^(?:h\d|title|strong)$/));
}

sub find_heading ( $ ) {
  my ($node) = @_;
  my (@headings) = get_headings($node);
  @headings and return $headings[0];
 SEARCH_LEFT:
  while ($node) {
    if (scalar $node->left) {
      $node = $node->left;
    } else {
      $node = $node->parent;
      redo SEARCH_LEFT;
    }
    @headings = get_headings($node);
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
  my $parent1_text = get_text($tag->parent) if $SHOW_PARENT1_TEXT;
  my $heading = find_heading($tag) if $SHOW_HEADING;
  $heading = $heading ? get_text($heading) : '' if $SHOW_HEADING;
  push @pages, { href => $href, heading => $heading,
		 parent1_text => $parent1_text, text => $text };
}

my @fields = ();
# should be in order of appearance!
push @fields, 'heading' if $SHOW_HEADING;
push @fields, 'parent1_text' if $SHOW_PARENT1_TEXT;
push @fields, 'text' if $SHOW_TEXT;
push @fields, 'href';

print join("\t", @$_{@fields}) . "\n" for @pages;
