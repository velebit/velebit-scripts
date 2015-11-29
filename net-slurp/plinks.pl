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

our $VERBOSITY = 0;
our $SHOW_HEADING = 0;
our $SHOW_TEXT = 0;
our $SHOW_PARENT1_TEXT = 0;
our $SHOW_SAME_LINE_TEXT = 0;
our $STRONG_IS_HEADING_TOO = 0;
our $TABLE_LEVEL;
GetOptions('--verbose|v+' => \$VERBOSITY,
	   '--show-heading|h!' => \$SHOW_HEADING,
	   '--bold-is-heading|b' =>
	   sub { $STRONG_IS_HEADING_TOO = 1;  $SHOW_HEADING = 1 },
	   '--show-text|t!' => \$SHOW_TEXT,
	   '--show-parent-text|pt!' => \$SHOW_PARENT1_TEXT,
	   '--show-line-text|lt!' => \$SHOW_SAME_LINE_TEXT,
	   '--table-level|tl=i' => \$TABLE_LEVEL,
	   '--not-in-table' => sub { $TABLE_LEVEL = 0 },
          ) or Usage;
@ARGV == 1 or Usage;


printf STDERR "    %-67s ", "Reading page..." if $VERBOSITY;
my $tree = HTML::TreeBuilder->new;
$tree->parse_file($ARGV[0]);
$tree->objectify_text();
print STDERR "done.\n" if $VERBOSITY;


sub get_text ( @ ) {
  my (@nodes) = @_;
  @nodes = grep defined, @nodes;
  return '' unless @nodes;
  @nodes = map $_->clone, @nodes;
  my $text = join '', map(($_->deobjectify_text() || $_->as_text), @nodes);
  # 0xA0 is a non-breaking space in Latin-1 and Unicode.
  # 0xC2 0xA0 is the UTF-8 representation of U+00A0; this is a horrible hack.
  $text =~ s/[\s\xA0\xC2]+/ /sg;
  $text =~ s/^ //;  $text =~ s/ $//;
  $text;
}


sub get_same_line_siblings ( $ ) {
  my ($node) = @_;
  return '' unless $node;
  my @list = ($node);
  {
    my $prev = $node;
    while (1) {
      $prev = $prev->left or last;
      $prev->look_down(_tag => qr/^(?:br|hr)$/) and last;
      unshift @list, $prev;
    }
  }
  {
    my $next = $node;
    while (1) {
      $next = $next->right or last;
      $next->look_down(_tag => qr/^(?:br|hr)$/) and last;
      push @list, $next;
    }
  }
  # TODO: go to parent if list has only 1 node?
  @list;
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

my %headings_cache;
sub traverse_to_heading ( $ );

sub traverse_to_heading ( $ ) {
  my ($node) = @_;
  return unless $node;
  return $headings_cache{$node}
    if exists $headings_cache{$node};

  for my $left (reverse $node->left) {
    return $headings_cache{$left}
      if exists $headings_cache{$left};
    my @headings = get_headings($left);
    @headings and return $headings_cache{$node} = $headings[-1];
  }

  $headings_cache{$node} = traverse_to_heading $node->parent;
}

sub find_heading ( $ ) {
  my ($node) = @_;
  my (@headings) = get_headings($node);
  # For our own headings, we pick the first, but don't cache it.
  @headings and return $headings[0];

  traverse_to_heading $node;
}

sub find_heading_text ( $ ) {
  my ($node) = @_;
  my ($heading) = find_heading($node);
  $heading ? get_text($heading) : '';
}


# only look at <a ...> tags
printf STDERR "    %-67s ", "Traversing <a> tags..." if $VERBOSITY;
my @pages = grep defined $_->{href},
  map +{ tag => $_, href => $_->attr('href') }, $tree->look_down(_tag => 'a');
print STDERR "done.\n" if $VERBOSITY;

if (defined $TABLE_LEVEL) {
  printf STDERR "    %-67s ", "Limiting by table level..." if $VERBOSITY;
  @pages = grep scalar(@{[$_->{tag}->look_up(_tag => 'table')]}) == $TABLE_LEVEL, @pages;
  print STDERR "done.\n" if $VERBOSITY;
}

if ($SHOW_TEXT) {
  printf STDERR "    %-67s ", "Extracting tag text..." if $VERBOSITY;
  $_->{text} = get_text($_->{tag}) for @pages;
  print STDERR "done.\n" if $VERBOSITY;
}

if ($SHOW_PARENT1_TEXT) {
  printf STDERR "    %-67s ", "Extracting parent text..." if $VERBOSITY;
  $_->{parent1_text} = get_text($_->{tag}->parent) for @pages;
  print STDERR "done.\n" if $VERBOSITY;
}

if ($SHOW_SAME_LINE_TEXT) {
  printf STDERR "    %-67s ", "Extracting text on the same line..." if $VERBOSITY;
  $_->{same_line_text} = get_text(get_same_line_siblings($_->{tag})) for @pages;
  print STDERR "done.\n" if $VERBOSITY;
}

if ($SHOW_HEADING) {
  printf STDERR "    %-67s ", "Extracting headings..." if $VERBOSITY;
  $_->{heading} = find_heading_text($_->{tag}) for @pages;
  print STDERR "done.\n" if $VERBOSITY;
}


printf STDERR "    %-67s ", "Producing output..." if $VERBOSITY;
my @fields = ();
# should be in order of appearance!
push @fields, 'heading' if $SHOW_HEADING;
push @fields, 'parent1_text' if $SHOW_PARENT1_TEXT;
push @fields, 'same_line_text' if $SHOW_SAME_LINE_TEXT;
push @fields, 'text' if $SHOW_TEXT;
push @fields, 'href';

print join("\t", @$_{@fields}) . "\n" for @pages;
print STDERR "done.\n" if $VERBOSITY;
