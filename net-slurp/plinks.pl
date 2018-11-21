#!/usr/bin/perl
# Show all links in a given page (file).
use warnings;
use strict;

use Getopt::Long;
use HTML::TreeBuilder;
use URI;

$| = 1;

sub Usage () {
  die "Usage: $0 [-v] [-h] [-hb] [-pt] [-lt] [-t] [--table-level LEVEL]" .
      " [--base BASE] FILE\n";
  exit 1;
}

our $WHITESPACE_MAX_IGNORED = 1;
our $WHITESPACE_DELTA_IGNORED = 0;

our $VERBOSITY = 0;
our $SHOW_HEADING = 0;
our $SHOW_STRONG_OR_HEADING = 0;
our $SHOW_PARENT1_TEXT = 0;
our $SHOW_PRECEDING_LESS_INDENTED_TEXT = 0;
our $SHOW_SAME_LINE_TEXT = 0;
our $SHOW_SAME_LINE_NUM_LINKS = 0;
our $SHOW_TEXT = 0;
our $TABLE_LEVEL;
our $BASE_URI;
GetOptions('verbose|v+' => \$VERBOSITY,
	   'show-heading|h!' => \$SHOW_HEADING,
	   'bold-is-heading|b' =>
	   sub { die("Option --bold-is-heading (-b) is deprecated." .
		     "  Try --show-bold-or-heading (-hb)?\n\n"); },
	   'show-bold-or-heading|hb!' => \$SHOW_STRONG_OR_HEADING,
	   'show-parent-text|pt!' => \$SHOW_PARENT1_TEXT,
	   'show-less-indented|li:999' => \$SHOW_PRECEDING_LESS_INDENTED_TEXT,
	   'show-line-text|lt!' => \$SHOW_SAME_LINE_TEXT,
	   'show-line-links|ll!' => \$SHOW_SAME_LINE_NUM_LINKS,
	   'show-text|t!' => \$SHOW_TEXT,
	   'table-level|tl=i' => \$TABLE_LEVEL,
	   'not-in-table' => sub { $TABLE_LEVEL = 0 },
	   'base=s' => \$BASE_URI,
          ) or Usage;
@ARGV == 1 or Usage;


printf STDERR "    %-67s ", "Reading page..." if $VERBOSITY;
my $tree = HTML::TreeBuilder->new;
$tree->parse_file($ARGV[0]);
$tree->objectify_text();
print STDERR "done.\n" if $VERBOSITY;


sub get_raw_text ( @ ) {
  my (@nodes) = @_;
  @nodes = grep defined, @nodes;
  return '' unless @nodes;
  @nodes = map $_->clone, @nodes;
  my $text = join '', map(($_->deobjectify_text() || $_->as_text), @nodes);
  $text;
}


sub get_text ( @ ) {
  my (@nodes) = @_;
  my $text = get_raw_text(@nodes);
  # 0xA0 is a non-breaking space in Latin-1 and Unicode.
  # 0xC2 0xA0 is the UTF-8 representation of U+00A0; this is a horrible hack.
  $text =~ s/[\s\xA0\xC2]+/ /sg;
  $text =~ s/^ //;  $text =~ s/ $//;
  $text;
}


sub get_num_links ( @ ) {
  my (@nodes) = @_;
  my @links = map $_->look_down(_tag => 'a'), grep defined, @nodes;
  scalar @links;
}


sub get_leading_whitespace_amount ( @ ) {
  my (@nodes) = @_;
  my $text = join '', map get_raw_text($_), grep defined, @nodes;
  s/\t/    /g;  # HACK: treat each tab like 4 spaces
  $text =~ s/\xA0/ /g;  $text =~ s/\xC2//g;
  my $whitespace = (($text =~ /^( +)/) ? length $1 : 0);
  ($whitespace > $WHITESPACE_MAX_IGNORED) ? $whitespace : 0;
}


sub get_same_line_siblings ( $ ) {
  my ($node) = @_;
  return () unless $node;
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


sub get_previous_line_siblings ( $ ) {
  my ($node) = @_;
  return () unless $node;
  {
    while (1) {
      $node->look_down(_tag => qr/^(?:br|hr)$/) and last;
      $node = $node->left or return ();
    }
  }
  my @list = ($node);
  {
    my $prev = $node;
    while (1) {
      $prev = $prev->left or last;
      $prev->look_down(_tag => qr/^(?:br|hr)$/) and last;
      unshift @list, $prev;
    }
  }
  @list;
}


sub get_preceding_less_indented_lines_text ( $;$ ) {
  my ($node, $max_lines) = @_;
  return '' unless $node;
  my $indent = 0;
  {
    my @current = get_same_line_siblings($node);
    $indent = get_leading_whitespace_amount(@current);
    $node = $current[0] if @current;
  }
  my @lines;
  {
  LINE:
    while ($node and $indent > $WHITESPACE_DELTA_IGNORED) {
      my @previous = get_previous_line_siblings($node)
	or last LINE;
      my $previous_indent = get_leading_whitespace_amount(@previous);
      $node = $previous[0];
      if ($previous_indent < ($indent - $WHITESPACE_DELTA_IGNORED)) {
	unshift @lines, get_text(@previous);
	$indent = $previous_indent;
	defined $max_lines and @lines == $max_lines and last LINE;
      }
    }
  }
  my $separator = ' // ';
  join $separator, @lines;
}


sub nonempty ( @ ) {
  grep(($_->tag ne '~text' or $_->attr('text') !~ /^[\s\xA0]+$/s), @_);
}


sub get_markup_headings ( $ ) {
  my ($node) = @_;
  return unless $node;
  $node->look_down(_tag => qr/^(?:title|h\d)$/);
}

sub get_display_headings ( $ ) {
  my ($node) = @_;
  return unless $node;
  my ($left, $right);
  grep(($_->tag ne 'strong'
	or ($_->parent->tag =~ /^(?:p|dt|div)$/
	    and ((($left = (nonempty($_->left))[-1]) ? $left->tag : '')
		 =~ /^(?:br|hr|)$/)
	    and ((($right = (nonempty($_->right))[0]) ? $right->tag : '')
		 =~ /^(?:br|)$/))),
       $node->look_down(_tag => qr/^(?:title|h\d|strong)$/));
}

my %headings_cache;
sub clear_headings_cache () {
  %headings_cache = ();
}

sub traverse_to_heading ( $$ );

sub traverse_to_heading ( $$ ) {
  my ($node, $get_headings) = @_;
  return unless $node;
  return $headings_cache{$node}
    if exists $headings_cache{$node};

  for my $left (reverse $node->left) {
    return $headings_cache{$left}
      if exists $headings_cache{$left};
    my @headings = $get_headings->($left);
    @headings and return $headings_cache{$node} = $headings[-1];
  }

  $headings_cache{$node} = traverse_to_heading($node->parent, $get_headings);
}

sub find_heading ( $$ ) {
  my ($node, $get_headings) = @_;
  my (@headings) = $get_headings->($node);
  # For our own headings, we pick the first, but don't cache it.
  @headings and return $headings[0];

  traverse_to_heading($node, $get_headings);
}

sub find_heading_text ( $$ ) {
  my ($node, $get_headings) = @_;
  my ($heading) = find_heading($node, $get_headings);
  $heading ? get_text($heading) : '';
}

sub get_table_level ( $ ) {
  my ($node) = @_;
  scalar(@{[$node->look_up(_tag => 'table')]});
}

sub absolute_uri ( $;$ ) {
    my ($uri, $base) = @_;
    $uri = URI->new_abs($uri, $base) unless $uri =~ /^#/;
    "$uri";
}


# only look at <a ...> tags
printf STDERR "    %-67s ", "Traversing <a> tags..." if $VERBOSITY;
my @fields = ();
my @pages = grep defined $_->{href},
  map +{ tag => $_, href => $_->attr('href') }, $tree->look_down(_tag => 'a');
print STDERR "done.\n" if $VERBOSITY;

if (defined $TABLE_LEVEL) {
  printf STDERR "    %-67s ", "Limiting by table level..." if $VERBOSITY;
  @pages = grep get_table_level($_->{tag}) == $TABLE_LEVEL, @pages;
  print STDERR "done.\n" if $VERBOSITY;
}

if ($SHOW_HEADING) {
  printf STDERR "    %-67s ", "Extracting headings..." if $VERBOSITY;
  clear_headings_cache;
  my $get_headings = \&get_markup_headings;
  $_->{heading} = find_heading_text($_->{tag}, $get_headings) for @pages;
  push @fields, 'heading';
  print STDERR "done.\n" if $VERBOSITY;
}

if ($SHOW_STRONG_OR_HEADING) {
  printf STDERR "    %-67s ", "Extracting heading/strongs..." if $VERBOSITY;
  clear_headings_cache;
  my $get_headings = \&get_display_headings;
  $_->{str_head} = find_heading_text($_->{tag}, $get_headings) for @pages;
  push @fields, 'str_head';
  print STDERR "done.\n" if $VERBOSITY;
}

if ($SHOW_PARENT1_TEXT) {
  printf STDERR "    %-67s ", "Extracting parent text..." if $VERBOSITY;
  $_->{parent1_text} = get_text($_->{tag}->parent) for @pages;
  push @fields, 'parent1_text';
  print STDERR "done.\n" if $VERBOSITY;
}

if ($SHOW_PRECEDING_LESS_INDENTED_TEXT > 0) {
  printf STDERR "    %-67s ", "Extracting text on the less indented line(s) in parent..." if $VERBOSITY;
  $_->{preceding_less_indented_text} =
    get_preceding_less_indented_lines_text(
      $_->{tag}, $SHOW_PRECEDING_LESS_INDENTED_TEXT)
      for @pages;
  push @fields, 'preceding_less_indented_text';
  print STDERR "done.\n" if $VERBOSITY;
}

if ($SHOW_SAME_LINE_TEXT) {
  printf STDERR "    %-67s ", "Extracting text on the same line..." if $VERBOSITY;
  $_->{same_line_text} = get_text(get_same_line_siblings($_->{tag})) for @pages;
  push @fields, 'same_line_text';
  print STDERR "done.\n" if $VERBOSITY;
}

if ($SHOW_SAME_LINE_NUM_LINKS) {
  printf STDERR "    %-67s ", "Extracting # links on the same line..." if $VERBOSITY;
  $_->{same_line_num_links} = get_num_links(get_same_line_siblings($_->{tag})) for @pages;
  push @fields, 'same_line_num_links';
  print STDERR "done.\n" if $VERBOSITY;
}

if ($SHOW_TEXT) {
  printf STDERR "    %-67s ", "Extracting tag text..." if $VERBOSITY;
  $_->{text} = get_text($_->{tag}) for @pages;
  push @fields, 'text';
  print STDERR "done.\n" if $VERBOSITY;
}

if ($BASE_URI) {
    $_->{href_abs} = absolute_uri($_->{href}, $BASE_URI) for @pages;
    push @fields, 'href_abs';
} else {
    push @fields, 'href';
}

printf STDERR "    %-67s ", "Producing output..." if $VERBOSITY;
print join("\t", @$_{@fields}) . "\n" for @pages;
print STDERR "done.\n" if $VERBOSITY;
