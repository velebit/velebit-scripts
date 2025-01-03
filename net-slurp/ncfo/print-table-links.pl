#!/usr/bin/perl
# Show all links in tables in a given page (file).
# Based on plinks (for framework) and extract-column-links (for table handling).
use warnings;
use strict;
use open ':std', ':encoding(UTF-8)';

use Getopt::Long;
use HTML::TreeBuilder;
# Doesn't use HTML::TableExtract in 'tree' mode because it doesn't seem to
# let us access the whole tree.  Doesn't use other existing modules for a
# wide variety of reasons, including I can't look through all of them.
use URI;
use Carp qw( carp croak );
use Unicode::Normalize ();
use Text::Unidecode;

$| = 1;

# ----------------------------------------------------------------------

sub Usage ( @ ) {
  die join "\n\n", @_, <<"EndOfMessage";
Usage: $0 [OPTIONS...] HTML_FILE
Arguments and general options:
  HTML_FILE                    The path of the input HTML file to be parsed.
  --verbose              (-v)  Print additional status messages to stderr.
                               Can be repeated.
  --base BASE_URI              Use BASE_URI as the base for relative links.
  --ascii-text           (-7)  Print text (but not the URI!) as ASCII, without
                               accents etc.
  --separator SEP              String used to separate entries when combined in
                               a single output field.  [default: ' // ']
Data selection options:
  --table-level LEVEL   (-tl)  Only show links within LEVEL nested tables.
  --ignore-breaks      (-ibr)  Don't use line breaks as "sub-row" delimiters.
                               By default, an "entry" is a break-delimited line
                               within a cell.  With -ibr, an "entry" is a cell.
  --merge-links         (-ml)  Treat adjacent links to same URI as one link.
Data ordering options:
  --sort-by-line        (-sl)  Order links by row *and line* before column.
  --output-by-line      (-ol)  Do --sort-by-line and repeat single-line links.
  --repeat-span          (-r)  Repeat links in row/column spans.
Output options (extra fields printed before URI, separated by tabs):
  --show-heading         (-h)  Show text of <h#> or <title> tag before table.
  --show-heading1       (-h1)  Show text of <h1> tag before table.
  --show-heading2       (-h2)  Show text of <h2> tag before table.
  --show-bold-or-heading
                        (-hb)  Show text of <strong>, <h#> or <title> tag
                               before the table, with some heuristic filtering.
  --show-row-number     (-nr)  Show the row number where the link occurs.
  --show-column-number  (-nc)  Show the column number where the link occurs.
  --show-cell-line-number
                        (-nl)  Show the number of the line *within* the table
                               cell where the link occurs.  Probably useless
                               when -ibr is in effect.
  --show-same-entry-text
                        (-ee)  Show the text of the entry (line or cell) where
                               the link occurs.  (See also: -ibr.)
  --show-same-entry-text-before-links
                        (-eb)  Show the text of the entry (line or cell) up to
                               the first link.  (See also: -eu, -ibr.)
  --show-same-entry-text-after-links
                        (-ea)  Show the text of the entry (line or cell)
                               following the last link.  (See also: -ed, -ibr.)
  --show-same-entry-text-before-here
                        (-eu)  Show the text of the entry (line or cell) up to
                               the _active_ link; this includes any other links
                               before the active one.  (See also: -eb, -ibr.)
  --show-same-entry-text-after-here
                        (-ed)  Show the text of the entry (line or cell)
                               following the the _active_ link; this includes
                               any other links after the active one.
                               (See also: -ea, -ibr.)
  --show-text-at ROW,COLUMN
                        (-at)  Show the text of the cell (TODO: entry?)
                               in row ROW and column COLUMN.
  --show-text-at-column COLUMN
                        (-ec)  Show the text of the entry (line or cell) in
                               column COLUMN, and the same row/line as the link.
                               (See also: -ibr.)
  --show-text-at-row ROW
                        (-er)  Show the text of the cell (TODO: entry?)
                               in row ROW, and the same column as the link.
  --show-same-row-text
                        (-rr)  Show the text of the entries in the same row
                               and line as the link.  (With -ibr, the line is
                               ignored, and entire cells are shown.)
  --show-same-row-text-before-cell
                        (-rb)  Show the text of the entries in the same row
                               and line as the link, left of the cell with the
                               link.  (With -ibr, the line is ignored, and
                               entire cells are shown.)
  --show-same-row-text-after-cell
                        (-ra)  Show the text of the entries in the same row
                               and line as the link, right of the cell with the
                               link.  (With -ibr, the line is ignored, and
                               entire cells are shown.)
  --show-text            (-t)  Show text of the link itself.
EndOfMessage
  exit 1;  # backstop
}


use constant PRE_TABLE_HEADING => 'pre_table_heading';
use constant PRE_TABLE_HEADING1 => 'pre_table_heading1';
use constant PRE_TABLE_HEADING2 => 'pre_table_heading2';
use constant PRE_TABLE_STRONG_OR_HEADING => 'pre_table_str_head';
use constant ROW_NUMBER => 'row';
use constant COLUMN_NUMBER => 'column';
use constant CELL_LINE_NUMBER => 'cell_line';
use constant SAME_ENTRY_TEXT => 'same_entry';
use constant SAME_ENTRY_TEXT_BEFORE_LINKS => 'same_entry_before_links';
use constant SAME_ENTRY_TEXT_AFTER_LINKS => 'same_entry_after_links';
use constant SAME_ENTRY_TEXT_BEFORE_CURRENT => 'same_entry_before_current';
use constant SAME_ENTRY_TEXT_AFTER_CURRENT => 'same_entry_after_current';
use constant ENTRY_TEXT_AT_ROW_COL_prefix => 'at_row_col=';
use constant SAME_ROW_ENTRY_TEXT_AT_COLUMN_prefix => 'same_row_at_col=';
use constant SAME_COLUMN_ENTRY_TEXT_AT_ROW_prefix => 'same_col_at_row=';
use constant SAME_ROW_TEXT => 'same_row';
use constant SAME_ROW_TEXT_BEFORE_CELL => 'same_row_before';
use constant SAME_ROW_TEXT_AFTER_CELL => 'same_row_after';
use constant TEXT => 'text';


our @fields;

# NB: this implementation matches plinks (or did at one point).
sub add_rm_field ( $$ ) {
  my ($name, $add) = @_;
  if ($add) {
    push @fields, $name;
  } else {
    @fields = grep $_ ne $name, @fields;
  }
}

# NB: this implementation matches plinks (or did at one point).
sub has_field ( $ ) {
  my ($name) = @_;
  scalar grep $_ eq $name, @fields;
}

# NB: this implementation matches plinks (or did at one point).
sub unique ( @ ) {
  my (%seen);
  grep !($seen{$_}++), @_;
}

# NB: this implementation matches plinks (or did at one point).
sub get_matching_fields ( $ ) {
  my ($prefix) = @_;
  unique grep $_ =~ qr/^\Q$prefix\E/, @fields;
}

# NB: this implementation matches plinks (or did at one point).
sub strip_prefix ( $$ ) {
  my ($value, $prefix) = @_;
  $value =~ s/^\Q$prefix\E// or return;
  $value;
}


our $VERBOSITY = 0;
our $TABLE_LEVEL;
our $BASE_URI;
our $TEXT_AS_ASCII = 0;
our $MERGE_LINKS = 0;

our $SPLIT_AT_LINE_BREAKS = 1;
our $CELL_SEPARATOR = ' // ';
our $REORDER_BY_LINE = 0;
our $REPEAT_SPAN = 0;
our $REPEAT_SINGLE_LINE = 0;

GetOptions('verbose|v+' => \$VERBOSITY,
           'base=s' => \$BASE_URI,
           'ascii-text|7!' => \$TEXT_AS_ASCII,
           'separator=s' => \$CELL_SEPARATOR,
           'table-level|tl=i' => \$TABLE_LEVEL,
           'ignore-breaks|ibr!' => sub { $SPLIT_AT_LINE_BREAKS = ! $_[1] },
           'merge-links|ml!' => \$MERGE_LINKS,
           'sort-by-line|sl!' => \$REORDER_BY_LINE,
           'output-by-line|by-line|ol!' =>
           sub { $REORDER_BY_LINE = $REPEAT_SINGLE_LINE = $_[1] },
           'repeat-span|r!' => \$REPEAT_SPAN,
           'show-heading|h!' =>
           sub { add_rm_field PRE_TABLE_HEADING, $_[1] },
           'show-heading1|h1!' =>
           sub { add_rm_field PRE_TABLE_HEADING1, $_[1] },
           'show-heading2|h2!' =>
           sub { add_rm_field PRE_TABLE_HEADING2, $_[1] },
           'show-bold-or-heading|hb!' =>
           sub { add_rm_field PRE_TABLE_STRONG_OR_HEADING, $_[1] },
           'show-row-number|nr' =>
           sub { add_rm_field ROW_NUMBER, $_[1] },
           'show-column-number|nc' =>
           sub { add_rm_field COLUMN_NUMBER, $_[1] },
           'show-cell-line-number|nl' =>
           sub { add_rm_field CELL_LINE_NUMBER, $_[1] },
           'show-same-entry-text|entry-text|ee!' =>
           sub { add_rm_field SAME_ENTRY_TEXT, $_[1] },
           'show-same-entry-text-before-links|eb!' =>
           sub { add_rm_field SAME_ENTRY_TEXT_BEFORE_LINKS, $_[1] },
           'show-same-entry-text-after-links|ea!' =>
           sub { add_rm_field SAME_ENTRY_TEXT_AFTER_LINKS, $_[1] },
           'show-same-entry-text-before-here|eu!' =>
           sub { add_rm_field SAME_ENTRY_TEXT_BEFORE_CURRENT, $_[1] },
           'show-same-entry-text-after-here|ed!' =>
           sub { add_rm_field SAME_ENTRY_TEXT_AFTER_CURRENT, $_[1] },
           'show-text-at|at=s' =>
           sub { my ($r, $c) = ($_[1] =~ /^(\d+),(\d+)$/) or die;
                 add_rm_field ENTRY_TEXT_AT_ROW_COL_prefix . "$r,$c", 1 },
           'show-text-at-column|at-column|ec=i' =>
           sub { add_rm_field SAME_ROW_ENTRY_TEXT_AT_COLUMN_prefix . $_[1], 1 },
           'show-text-at-row|at-row|er=i' =>
           sub { add_rm_field SAME_COLUMN_ENTRY_TEXT_AT_ROW_prefix . $_[1], 1 },
           'show-same-row-text|row-text|rr!' =>
           sub { add_rm_field SAME_ROW_TEXT, $_[1] },
           'show-same-row-text-before-cell|row-before|rb!' =>
           sub { add_rm_field SAME_ROW_TEXT_BEFORE_CELL, $_[1] },
           'show-same-row-text-after-cell|row-after|ra!' =>
           sub { add_rm_field SAME_ROW_TEXT_AFTER_CELL, $_[1] },
           'show-text|t!' =>
           sub { add_rm_field TEXT, $_[1] },
          ) or Usage;
@ARGV >= 1 or Usage "File name not provided.";
@ARGV <= 1 or Usage "Too many arguments provided.";


printf STDERR "    %-67s ", "Reading page..." if $VERBOSITY;
my $tree = HTML::TreeBuilder->new;
open my $file, '<:encoding(UTF-8)', $ARGV[0]
  or die "Could not open $ARGV[0]: $!\n";
$tree->parse_file($file) or die "Could not parse $ARGV[0]: $!\n";
$tree->objectify_text();
print STDERR "done.\n" if $VERBOSITY;


# NB: this implementation matches plinks/e-c-l (or did at one point).
sub get_raw_text ( @ ) {
  my (@nodes) = @_;
  @nodes = grep defined, @nodes;
  return '' unless @nodes;
  @nodes = map $_->clone, @nodes;
  my $text = join '', map(($_->deobjectify_text() || $_->as_text), @nodes);
  $text;
}


# NB: this implementation matches plinks/e-c-l (or did at one point).
sub get_text ( @ ) {
  my (@nodes) = @_;
  my $text = get_raw_text(@nodes);
  $text = Unicode::Normalize::NFKC($text);
  # 0xA0 is a non-breaking space in Latin-1 and Unicode.
  # 0xC2 0xA0 is the UTF-8 representation of U+00A0; this is a horrible hack
  # (which may no longer be needed; not bothering to test.)
  $text =~ s/[\s\xA0\xC2]+/ /sg;
  $text =~ s/^ //;  $text =~ s/ $//;
  $text = unidecode($text) if $TEXT_AS_ASCII;
  $text;
}


# NB: this implementation matches plinks/e-c-l (or did at one point).
sub get_divergent_lineage ( $$ ) {
  my ($from, $to) = @_;
  croak if !defined $from or !defined $to;
  my @fparents = ($from, $from->lineage);
  my @tparents = ($to, $to->lineage);
  pop(@fparents), pop(@tparents)
    while @fparents and @tparents and $fparents[-1] == $tparents[-1];
  return (\@fparents, \@tparents);
}


# NB: this implementation matches plinks/e-c-l (or did at one point).
sub get_in_between_nodes ( $$ ) {
  my ($from, $to) = @_;
  $from->root == $to->root or return ();  # not same root -> span is ()
  my ($fparents, $tparents) = get_divergent_lineage($from, $to) or return ();
  my $ftop = pop(@$fparents);
  my $ttop = pop(@$tparents);
  $ftop or $ttop or return ();  # same node -> span is ()
  if ($ftop and $ttop) {
      $ftop->parent == $ttop->parent or croak;  # inconsistent lineage -> error
      $ftop->pindex >= $ttop->pindex
        and return ();  # nodes are in reverse order -> span is ()
  }
  my @span;
  push @span, $_->right for @$fparents;
  if (! $ftop) {
    push @span, $ttop->left;
  } elsif (! $ttop) {
    push @span, $ftop->right;
  } else {
    push @span,
      @{$ftop->parent->content}[($ftop->pindex+1)..($ttop->pindex-1)];
  }
  push @span, $_->left for reverse @$tparents;
  return @span;
}


# NB: this implementation matches plinks (or did at one point).
sub try_merging_nodes ( $$;$$ ) {
  my ($first, $second, $good_nodes, $bad_nodes) = @_;
  defined $good_nodes or $good_nodes = qr/^(?:em|strong|b|i|div|span|~text)$/;
  defined $bad_nodes or $bad_nodes = qr/^(?:table|tr|th|td|br|hr|img)$/;

  my $can_merge = 1;
  my @lineages = get_divergent_lineage $first, $second
    or $can_merge = 0;
  (shift(@{$lineages[0]}) == $first or die) if @lineages;
  (shift(@{$lineages[1]}) == $second or die) if @lineages;
  my @in_between = get_in_between_nodes $first, $second;

  for my $e ([[map @$_, @lineages], 'parent'],
	     [[map $_, @in_between], 'in-between'],
	     [[map $_->descendants, @in_between], 'in-between child']) {
    my ($nodes, $kind) = @$e;
    for my $node (@$nodes) {
      my $tag = $node->tag;
      if ($tag =~ $bad_nodes) {
	$can_merge = 0;
      } elsif ($tag !~ $good_nodes) {
	warn("warning: while merging, $kind node '$tag' is neither" .
	     " good nor bad! (ignoring)");
	$node->dump(\*STDERR);
      }
    }
  }
  return 0 unless $can_merge;

  # The in-between nodes should not contain any non-whitespace text.
  for my $node (@in_between) {
    get_text($node) eq ''
      or return 0;
  }

  # Attach all of the relevant nodes to the end of the *first* node.
  $_->detach for @in_between;
  $first->push_content(@in_between, $second->detach_content);
  $second->destroy();
  return 1;
}


# NB: this implementation matches extract-column-links (or did at one point).
sub count_line_breaks_in ( @ ) {
  my (@nodes) = @_;
  my $count = 0;
  $count += scalar @{[ $_->look_down(_tag => qr/^(?:br|hr)$/) ]}
    for @nodes;
  $count;
}


# NB: this implementation matches extract-column-links (or did at one point).
sub count_line_breaks ( $ ) {
  my ($node) = @_;
  count_line_breaks_in $node->left;
}


# NB: this implementation matches extract-column-links (or did at one point).
sub get_line_edges ( $$ ) {
  my ($parent, $number) = @_;
  return unless $parent;
  return ($parent, $parent) unless defined $number;
  my @edges = $parent->look_down(_tag => qr/^(?:br|hr)$/);
  @edges or return ($parent, $parent);
  $number == 0 and return ($parent, $edges[0]);
  $number <= $#edges and return ($edges[$number-1], $edges[$number]);
  $number == ($#edges+1) and return ($edges[$number-1], $parent);
  return;
}

# NB: this implementation matches extract-column-links (or did at one point).
sub get_line_by_number ( $$ ) {
  my ($parent, $number) = @_;
  my ($from, $to) = get_line_edges $parent, $number or return;
  $from == $to and return $from;  # if no breaks (or no number), return cell
  get_in_between_nodes $from, $to;
}


sub get_entry ( $$$;$ ) {
  my ($table, $row, $column, $line) = @_;
  ($row >= 0 and $row < $table->{rows})
    or croak "Row $row is not 0..@{[$table->{rows}-1]}";
  ($column >= 0 and $column < $table->{columns})
    or croak "Column $column is not 0..@{[$table->{columns}-1]}";
  my @entry = ( $table->{cells}[$row][$column] );
  @entry = get_line_by_number $entry[0], $line if defined $line;
  @entry;
}

sub get_entries ( $$$;$ ) {
  my ($table, $rows, $columns, $lines) = @_;
  $rows = [$rows] if ! ref $rows;
  $columns = [$columns] if ! ref $columns;
  $lines = [$lines] if ! defined $lines or ! ref $lines;
  my @entries;
  for my $r (@$rows) {
    for my $c (@$columns) {
      push @entries, map get_entry($table, $r, $c, $_), @$lines;
    }
  }
  @entries;
}


sub skip_first ( @ ) {
  my (@nodes) = @_;
  #shift @nodes;
  return @nodes;
}

sub skip_last ( @ ) {
  my (@nodes) = @_;
  #pop @nodes;
  return @nodes;
}


sub before_first_link ( @ ) {
  my (@nodes) = @_;
  my (@result);
  while (@nodes) {
    my $node = shift @nodes;
    for my $tag ($node->look_down(_tag => 'a')) {
      defined $tag->{href} or next;
      push @result, get_in_between_nodes $node, $tag;
      return @result;
    }
    push @result, $node;
  }
  return @result;
}

sub after_last_link ( @ ) {
  my (@nodes) = @_;
  my (@result);
  while (@nodes) {
    my $node = pop @nodes;
    for my $tag (reverse $node->look_down(_tag => 'a')) {
      defined $tag->{href} or next;
      unshift @result, get_in_between_nodes $tag, $node;
      return @result;
    }
    unshift @result, $node;
  }
  return @result;
}


# NB: this implementation matches plinks (or did at one point).
sub nonempty ( @ ) {
  grep(($_->tag ne '~text' or $_->attr('text') !~ /^[\s\xA0]+$/s), @_);
}


# NB: this implementation matches plinks (or did at one point).
sub get_markup_headings ( $ ) {
  my ($node) = @_;
  return unless $node;
  $node->look_down(_tag => qr/^(?:title|h\d)$/);
}

# build_get_level_headings('hN') returns a sub ref that extracts hN headings
# NB: this implementation matches plinks (or did at one point).
sub build_get_level_headings ( $ ) {
  my ($tag) = @_;
  $tag =~ /^h\d$/ or die "Unexpected heading tag '$tag'";
  sub {
    my ($node) = @_;
    return unless $node;
    $node->look_down(_tag => qr/^(?:$tag)$/);
  };
}

# NB: this implementation matches plinks (or did at one point).
sub is_valid_display_heading ( $ ) {
  my ($node) = @_;
  return unless $node;
  return 1 if $node->tag =~ qr/^(?:title|h\d)$/;
  if ($node->tag eq 'strong') {
    return 0 unless $node->parent->tag =~ /^(?:p|dt|div)$/;

    my @left_nodes = nonempty($node->left);
    return 0 if @left_nodes and $left_nodes[-1]->tag !~ /^(?:br|hr)$/;

    if (0) {
      my @right_nodes = nonempty($node->right);
      shift @right_nodes if @right_nodes and $right_nodes[0]->tag eq 'a';
      return 0 if @right_nodes and $right_nodes[0]->tag ne 'br';
    }

    return 1;
  }
  0;
}

# NB: this implementation matches plinks (or did at one point).
sub get_display_headings ( $ ) {
  my ($node) = @_;
  return unless $node;
  grep(is_valid_display_heading($_),
       $node->look_down(_tag => qr/^(?:title|h\d|strong)$/));
}

my %headings_cache;
sub clear_headings_cache () {
  %headings_cache = ();
}

sub traverse_to_heading ( $$ );

# NB: this implementation matches plinks (or did at one point).
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

# NB: this implementation matches plinks (or did at one point).
sub find_heading ( $$ ) {
  my ($node, $get_headings) = @_;
  my (@headings) = $get_headings->($node);
  # For our own headings, we pick the first, but don't cache it.
  @headings and return $headings[0];

  traverse_to_heading($node, $get_headings);
}

# NB: this implementation matches plinks (or did at one point).
sub find_heading_text ( $$ ) {
  my ($node, $get_headings) = @_;
  my ($heading) = find_heading($node, $get_headings);
  $heading ? get_text($heading) : '';
}

# NB: this implementation matches plinks (or did at one point).
sub get_table_level ( $ ) {
  my ($node) = @_;
  scalar(@{[$node->look_up(_tag => 'table')]});
}

# NB: this implementation matches plinks (or did at one point).
sub absolute_uri ( $;$ ) {
    my ($uri, $base) = @_;
    $uri = URI->new_abs($uri, $base) unless $uri =~ /^#/;
    "$uri";
}


# first, look at <a ...> tags inside <table ...> tags
printf STDERR "    %-67s ", "Traversing <a> and <table> tags..." if $VERBOSITY;
if ($VERBOSITY >= 2) {
  print STDERR "\n";
  print STDERR "        Total <a> tags: ";
  print STDERR scalar @{[$tree->look_down(_tag => 'a')]}, "\n";
  print STDERR "        Total <table> tags: ";
  print STDERR scalar @{[$tree->look_down(_tag => 'table')]}, "\n";
}
my (@links, %links, @tables, %tables, @prev, %stats);
LINK:
for my $tag ($tree->look_down(_tag => 'a')) {
    defined $tag->{href} or ($stats{"00:without href"}++, next);
    my $table_tag = $tag->look_up(_tag => 'table')
      or ($stats{"10:outside <table>"}++, @prev=(), next);
    # limit by $TABLE_LEVEL here if set
    defined $TABLE_LEVEL and get_table_level($tag) != $TABLE_LEVEL
      and ($stats{"15:at different <table> level"}++, @prev=(), next);

    if (! exists $tables{$table_tag}) {
      push @tables, +{ tag => $table_tag, links => [] };
      $tables{$table_tag} = $tables[-1];
    }
    my $table = $tables{$table_tag} or croak;
    my $link = { tag => $tag, href => $tag->attr('href'), table => $table };
    if ($MERGE_LINKS and @prev and $prev[0]->{href} eq $link->{href}) {
      # adjacent links to same URI, not sure if can merge
      try_merging_nodes($prev[0]->{tag}, $link->{tag})
        and ($stats{"30:merged with neighbors"}++, next LINK);
    }
    push @links, $link;
    $links{$tag} = $link;
    push @{ $table->{links} }, $link;
    @prev = ($link);
    $stats{"90:collected"}++;
}
if ($VERBOSITY >= 2) {
  print STDERR "        Number of <a> tags @{[substr($_, 3)]}: $stats{$_}\n"
    for sort keys %stats;
  print STDERR "        Number of <table>s collected: @{[scalar @tables]}\n";
  %stats = ();
  print STDERR "    ";
}
print STDERR "done.\n" if $VERBOSITY;

if (@tables) {
  printf STDERR "    %-67s ", "Building tables..." if $VERBOSITY;
  for my $t (0..$#tables) {
    my $table = $tables[$t];
    my @rows = $table->{tag}->content_list;
    (@rows == 1 or (@rows == 2 and $rows[0]->tag eq 'thead'))
      and $rows[-1]->tag eq 'tbody'
      and @rows = map $_->content_list, @rows;
    @rows = grep +($_->tag eq 'th' or $_->tag eq 'tr'), @rows;

    my @cells;
    my @in_rowspan = map [], 1..@rows;
    for my $r (0..$#rows) {
      my $c = -1;
      for my $cell ($rows[$r]->content_list) {
        $cell->tag =~ /^t[hd]$/ or croak "unexpected tag @{[$cell->tag]}";
        ++$c while $in_rowspan[$r][$c+1];
        for (0..(($cell->attr('colspan') || 1)-1)) {
          ++$c;
          $in_rowspan[$r][$c]
            and croak "row span/column span intersection";
          $cells[$r][$c] = $cell;
          $cells[$r+$_][$c] = $cell, ++$in_rowspan[$r+$_][$c]
            for 1..(($cell->attr('rowspan') || 1)-1);
        }
      }
      ++$c while $c < $#{$in_rowspan[$r]} && $in_rowspan[$r][$c+1];
      $c < $#{$cells[$r]} and croak;
      $c > $#{$cells[$r]} and warn "short line";
      $#{$cells[$r]} = $c;
    }
    $table->{cells} = \@cells;
    $table->{rows} = scalar @cells;
    $table->{columns} = $cells[0] ? scalar @{$cells[0]} : 0;

    for my $r (0..($table->{rows}-1)) {
      my $n0 = $table->{columns};
      my $nR = @{$cells[$r]};
      if ($nR != $n0) {
        my $context = ' (no context available)';
        $context = " (near @{[$cells[$r][-1]->as_HTML]})"
          if $nR > 0 and defined $cells[$r][-1];
        $nR < $n0 and warn("warning: too few cells ($nR < $n0) in table $t," .
                           " row $r$context");
        $nR > $n0 and warn("warning: too many cells ($nR > $n0) in table $t," .
                           " row $r$context");
      }
    }
  }
  print STDERR "done.\n" if $VERBOSITY;

  printf STDERR "    %-67s ", "Adjusting tables and links..." if $VERBOSITY;
  @tables = grep +($_->{rows} > 1 and $_->{columns} > 1), @tables;
  %tables = map +($_->{tag} => $_), @tables;
  @links = grep exists $tables{$_->{table}{tag}}, @links;
  %links = map +($_->{tag} => $_), @links;

  for my $table (@tables) {
    for my $r (0..($table->{rows}-1)) {
      my $row_num_lines = undef;
      my @cell_num_lines = (undef) x $table->{columns};
      for my $c (0..($table->{columns}-1)) {
        my $cell = $table->{cells}[$r][$c] or next;
        my $cell_num_line_breaks = count_line_breaks_in $cell;
        if ($cell_num_line_breaks > 0) {
          $cell_num_lines[$c] = $cell_num_line_breaks+1;
          (!defined $row_num_lines or $row_num_lines < $cell_num_lines[$c])
            and $row_num_lines = $cell_num_lines[$c];
        }
      }
      for my $c (0..($table->{columns}-1)) {
        my $cell = $table->{cells}[$r][$c] or next;
        my $cell_num_line_breaks = count_line_breaks_in $cell;
        for my $tag ($cell->look_down(_tag => 'a')) {
          exists $links{$tag} or next;  # skip already filtered out
          exists $links{$tag}{cell} and next;  # skip seen due to spans
          $links{$tag}{cell} = $cell;
          # these may be needed for many other checks/generators
          $links{$tag}{+ROW_NUMBER} = $r;
          $links{$tag}{+COLUMN_NUMBER} = $c;
          $links{$tag}{+CELL_LINE_NUMBER} = undef;
          $links{$tag}{row_span} = ($cell->attr('rowspan') || 1);
          $links{$tag}{column_span} = ($cell->attr('colspan') || 1);
          my $line_number =
            count_line_breaks_in get_in_between_nodes $cell, $tag
            if defined $cell_num_lines[$c];
          $links{$tag}{+CELL_LINE_NUMBER} = $line_number;
          $links{$tag}{original_cell_line_number} = $line_number;
          $links{$tag}{cell_num_lines} = $cell_num_lines[$c];
          $links{$tag}{row_num_lines} = $row_num_lines;
        }
      }
    }
  }
  (exists $_->{+ROW_NUMBER} and exists $_->{+COLUMN_NUMBER})
    or croak  $_->{href} for @links;
  print STDERR "done.\n" if $VERBOSITY;
}

sub replicate_span ( $ ) {
  my ($link) = @_;
  return $link if ! defined $link->{row_span};
  return $link if ! defined $link->{column_span};
  return $link if ($link->{row_span} == 1 and $link->{column_span} == 1);

  my @copies;
  for my $ri (0..($link->{row_span} - 1)) {
    for my $ci (0..($link->{column_span} - 1)) {
      my %link_copy = %$link;
      $link_copy{+ROW_NUMBER} += $ri;
      $link_copy{+COLUMN_NUMBER} += $ci;
      delete $link_copy{row_span}; delete $link_copy{column_span};
      push @copies, \%link_copy;
    }
  }

  # HACK: fix up %links bookkeeping too, as a side effect (!).
  $links{$copies[0]{tag}} = $copies[0];

  @copies;
}

sub replicate_if_single_line ( $ ) {
  my ($link) = @_;
  return $link if defined $link->{+CELL_LINE_NUMBER};
  return $link if ! defined $link->{row_num_lines};

  my @copies = map +{ %$link, (CELL_LINE_NUMBER) => $_ },
    0..($link->{row_num_lines}-1);

  # HACK: fix up %links bookkeeping too, as a side effect (!).
  $links{$copies[0]{tag}} = $copies[0];

  @copies;
}

if ($REPEAT_SPAN) {
  if (scalar grep((($_->{row_span} || 0) > 1 or ($_->{column_span} || 0) > 1),
                  @links)) {
    printf STDERR "    %-67s ", "Replicating spans..." if $VERBOSITY;
    @links = map replicate_span($_), @links;
    print STDERR "done.\n" if $VERBOSITY;
  }
}


if ($REPEAT_SINGLE_LINE) {
  if (scalar grep((! defined $_->{+CELL_LINE_NUMBER}
                   and defined $_->{row_num_lines}), @links)) {
    printf STDERR "    %-67s ", "Replicating single lines..." if $VERBOSITY;
    @links = map replicate_if_single_line($_), @links;
    print STDERR "done.\n" if $VERBOSITY;
  }
}


if ($REORDER_BY_LINE) {
  printf STDERR "    %-67s ", "Reordering links..." if $VERBOSITY;
  $links[$_]{original_order} = $_ for 0..$#links;
  {
      my $current_table = '';  # any non-undef value will do
      my $table_index = 0;
      for my $link (@links) {
          # update index on any table change, to deal w/ nested tables
          ++$table_index, ($current_table = $link->{table})
              if $current_table ne $link->{table};
          $link->{table_order} = $table_index;
      }
  }
  @links = sort { $a->{table_order} <=> $b->{table_order} or
                  $a->{+ROW_NUMBER} <=> $b->{+ROW_NUMBER} or
                  (($a->{+CELL_LINE_NUMBER} || -1) <=>
                   ($b->{+CELL_LINE_NUMBER} || -1)) or
                  $a->{+COLUMN_NUMBER} <=> $b->{+COLUMN_NUMBER} or
                  $a->{original_order} <=> $b->{original_order} } @links;
  print STDERR "done.\n" if $VERBOSITY;
}


if (has_field PRE_TABLE_HEADING) {
  printf STDERR "    %-67s ", "Extracting headings..." if $VERBOSITY;
  clear_headings_cache;
  my $get_headings = \&get_markup_headings;
  $_->{+PRE_TABLE_HEADING} =
    find_heading_text($_->{table}{tag}, $get_headings)
    for @links;
  print STDERR "done.\n" if $VERBOSITY;
}

for my $h ([PRE_TABLE_HEADING1, 'h1'], [PRE_TABLE_HEADING2, 'h2']) {
  my ($field, $tag) = @$h;
  if (has_field $field) {
    printf STDERR "    %-67s ", "Extracting $tag headings..." if $VERBOSITY;
    clear_headings_cache;
    my $get_headings = build_get_level_headings $tag;
    $_->{$field} =
      find_heading_text($_->{table}{tag}, $get_headings)
      for @links;
    print STDERR "done.\n" if $VERBOSITY;
  }
}

if (has_field PRE_TABLE_STRONG_OR_HEADING) {
  printf STDERR "    %-67s ", "Extracting heading/strongs..." if $VERBOSITY;
  clear_headings_cache;
  my $get_headings = \&get_display_headings;
  $_->{+PRE_TABLE_STRONG_OR_HEADING} =
    find_heading_text($_->{table}{tag}, $get_headings)
    for @links;
  print STDERR "done.\n" if $VERBOSITY;
}


if (has_field SAME_ENTRY_TEXT) {
  printf STDERR "    %-67s ", "Extracting text in the same entry..." if $VERBOSITY;
  for my $link (@links) {
    my $line = $link->{+CELL_LINE_NUMBER} if $SPLIT_AT_LINE_BREAKS;
    $link->{+SAME_ENTRY_TEXT} =
      get_text get_line_by_number $link->{cell}, $line;
  }
  print STDERR "done.\n" if $VERBOSITY;
}

if (has_field SAME_ENTRY_TEXT_BEFORE_LINKS) {
  printf STDERR "    %-67s ", "Extracting text in the same entry before first link..." if $VERBOSITY;
  for my $link (@links) {
    my $line = $link->{+CELL_LINE_NUMBER} if $SPLIT_AT_LINE_BREAKS;
    my ($text, $from, $to) = '';
    ($from, $to) = get_line_edges $link->{cell}, $line
      and $text = get_text before_first_link get_in_between_nodes $from, $link->{tag};
    $link->{+SAME_ENTRY_TEXT_BEFORE_LINKS} = $text;
  }
  print STDERR "done.\n" if $VERBOSITY;
}

if (has_field SAME_ENTRY_TEXT_AFTER_LINKS) {
  printf STDERR "    %-67s ", "Extracting text in the same entry after last link..." if $VERBOSITY;
  for my $link (@links) {
    my $line = $link->{+CELL_LINE_NUMBER} if $SPLIT_AT_LINE_BREAKS;
    my ($text, $from, $to) = '';
    ($from, $to) = get_line_edges $link->{cell}, $line
      and $text = get_text after_last_link get_in_between_nodes $link->{tag}, $to;
    $link->{+SAME_ENTRY_TEXT_AFTER_LINKS} = $text;
  }
  print STDERR "done.\n" if $VERBOSITY;
}


if (has_field SAME_ENTRY_TEXT_BEFORE_CURRENT) {
  printf STDERR "    %-67s ", "Extracting text in the same entry before this link..." if $VERBOSITY;
  for my $link (@links) {
    my $line = $link->{+CELL_LINE_NUMBER} if $SPLIT_AT_LINE_BREAKS;
    my ($text, $from, $to) = '';
    ($from, $to) = get_line_edges $link->{cell}, $line
      and $text = get_text skip_last get_in_between_nodes $from, $link->{tag};
    $link->{+SAME_ENTRY_TEXT_BEFORE_CURRENT} = $text;
  }
  print STDERR "done.\n" if $VERBOSITY;
}

if (has_field SAME_ENTRY_TEXT_AFTER_CURRENT) {
  printf STDERR "    %-67s ", "Extracting text in the same entry after this link..." if $VERBOSITY;
  for my $link (@links) {
    my $line = $link->{+CELL_LINE_NUMBER} if $SPLIT_AT_LINE_BREAKS;
    my ($text, $from, $to) = '';
    ($from, $to) = get_line_edges $link->{cell}, $line
      and $text = get_text skip_first get_in_between_nodes $link->{tag}, $to;
    $link->{+SAME_ENTRY_TEXT_AFTER_CURRENT} = $text;
  }
  print STDERR "done.\n" if $VERBOSITY;
}


{
  my @fields = get_matching_fields ENTRY_TEXT_AT_ROW_COL_prefix;
  if (@fields) {
    printf STDERR "    %-67s ", "Extracting fixed cells..." if $VERBOSITY;
    for my $field (@fields) {
      my ($row, $column) = split /,/,
        strip_prefix $field, ENTRY_TEXT_AT_ROW_COL_prefix;
      for my $link (@links) {
        $link->{$field} = get_text get_entry($link->{table},
                                             $row, $column, undef);
      }
    }
    print STDERR "done.\n" if $VERBOSITY;
  }
}

{
  my @fields = get_matching_fields SAME_ROW_ENTRY_TEXT_AT_COLUMN_prefix;
  if (@fields) {
    printf STDERR "    %-67s ", "Extracting fixed columns..." if $VERBOSITY;
    for my $field (@fields) {
      my $column = strip_prefix $field, SAME_ROW_ENTRY_TEXT_AT_COLUMN_prefix;
      for my $link (@links) {
        my $line = $link->{+CELL_LINE_NUMBER} if $SPLIT_AT_LINE_BREAKS;
        $link->{$field} = get_text get_entry($link->{table},
                                             $link->{row}, $column, $line);
      }
    }
    print STDERR "done.\n" if $VERBOSITY;
  }
}

{
  my @fields = get_matching_fields SAME_COLUMN_ENTRY_TEXT_AT_ROW_prefix;
  if (@fields) {
    printf STDERR "    %-67s ", "Extracting fixed rows..." if $VERBOSITY;
    for my $field (@fields) {
      my $row = strip_prefix $field, SAME_COLUMN_ENTRY_TEXT_AT_ROW_prefix;
      for my $link (@links) {
        $link->{$field} = get_text get_entry($link->{table},
                                             $row, $link->{column}, undef);
      }
    }
    print STDERR "done.\n" if $VERBOSITY;
  }
}


if (has_field SAME_ROW_TEXT) {
  printf STDERR "    %-67s ", "Extracting text in the same row..." if $VERBOSITY;
  for my $link (@links) {
    my $line = $link->{+CELL_LINE_NUMBER} if $SPLIT_AT_LINE_BREAKS;
    my $table = $link->{table};
    $link->{+SAME_ROW_TEXT} =
      join($CELL_SEPARATOR,
           map(get_text($_),
               get_entries($table,
                           $link->{row}, [ 0..($table->{columns}-1) ],
                           $line)));
  }
  print STDERR "done.\n" if $VERBOSITY;
}

if (has_field SAME_ROW_TEXT_BEFORE_CELL) {
  printf STDERR "    %-67s ", "Extracting text in the same row before cell..." if $VERBOSITY;
  for my $link (@links) {
    my $line = $link->{+CELL_LINE_NUMBER} if $SPLIT_AT_LINE_BREAKS;
    my $table = $link->{table};
    $link->{+SAME_ROW_TEXT_BEFORE_CELL} =
      join($CELL_SEPARATOR,
           map(get_text($_),
               get_entries($table,
                           $link->{row}, [ 0..($link->{column}-1) ],
                           $line)));
  }
  print STDERR "done.\n" if $VERBOSITY;
}

if (has_field SAME_ROW_TEXT_AFTER_CELL) {
  printf STDERR "    %-67s ", "Extracting text in the same row after cell..." if $VERBOSITY;
  for my $link (@links) {
    my $line = $link->{+CELL_LINE_NUMBER} if $SPLIT_AT_LINE_BREAKS;
    my $table = $link->{table};
    $link->{+SAME_ROW_TEXT_AFTER_CELL} =
      join($CELL_SEPARATOR,
           map(get_text($_),
               get_entries($table,
                           $link->{row},
                           [ ($link->{column}+1)..($table->{columns}-1) ],
                           $line)));
  }
  print STDERR "done.\n" if $VERBOSITY;
}

if (has_field TEXT) {
  printf STDERR "    %-67s ", "Extracting tag text..." if $VERBOSITY;
  $_->{+TEXT} = get_text($_->{tag}) for @links;
  print STDERR "done.\n" if $VERBOSITY;
}

# Fix up undefined CELL_LINE_NUMBERs
if (has_field CELL_LINE_NUMBER) {
  exists $_->{+CELL_LINE_NUMBER} and !defined $_->{+CELL_LINE_NUMBER}
    and $_->{+CELL_LINE_NUMBER} = '' for @links;
}

if ($BASE_URI) {
    $_->{href_abs} = absolute_uri($_->{href}, $BASE_URI) for @links;
    push @fields, 'href_abs';
} else {
    push @fields, 'href';
}

printf STDERR "    %-67s ", "Producing output..." if $VERBOSITY;
print join("\t", @$_{@fields}) . "\n" for @links;
print STDERR "done.\n" if $VERBOSITY;
