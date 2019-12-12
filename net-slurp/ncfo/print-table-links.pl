#!/usr/bin/perl
# Show all links in tables in a given page (file).
# Based on plinks (for framework) and extract-column-links (for table handling).
use warnings;
use strict;
use open ':std', ':encoding(UTF-8)';

use Getopt::Long;
use HTML::TreeBuilder;
# Doesn't use HTML::TableExtract in 'tree' mode because it doesn't seem to let us access the whole tree.
# Doesn't use other existing modules for a wide variety of reasons, including I can't look through all of them.
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
                               a single output field.
Data selection options:
  --table-level LEVEL   (-tl)  Only show links within LEVEL nested tables.
  --ignore-breaks      (-ibr)  Don't use line breaks as "sub-row" delimiters.
                               By default, an "entry" is a break-delimited line
                               within a cell.  With -ibr, an "entry" is a cell.
Data ordering options:
  --sort-by-line        (-sl)  Order links by row *and line* before column.
  --output-by-line      (-ol)  Do --sort-by-line and repeat single-line links.
Output options (extra fields printed before URI, separated by tabs):
  --show-heading         (-h)  Show text of <h#> or <title> tag before table.
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
  --show-same-entry-text-before-link
                        (-eb)  Show the text of the entry (line or cell) up to
                               the first link.  (See also: -ibr.)
  --show-same-entry-text-after-link
                        (-ea)  Show the text of the entry (line or cell)
                               following the last link.  (See also: -ibr.)
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
use constant PRE_TABLE_STRONG_OR_HEADING => 'pre_table_str_head';
use constant ROW_NUMBER => 'row';
use constant COLUMN_NUMBER => 'column';
use constant CELL_LINE_NUMBER => 'cell_line';
use constant SAME_ENTRY_TEXT => 'same_entry';
use constant SAME_ENTRY_TEXT_BEFORE_LINK => 'same_entry_before';
use constant SAME_ENTRY_TEXT_AFTER_LINK => 'same_entry_after';
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

our $SPLIT_AT_LINE_BREAKS = 1;
our $CELL_SEPARATOR = ' // ';
our $REORDER_BY_LINE = 0;
our $REPEAT_SINGLE_LINE = 0;

GetOptions('verbose|v+' => \$VERBOSITY,
           'base=s' => \$BASE_URI,
           'ascii-text|7!' => \$TEXT_AS_ASCII,
           'separator=s' => \$CELL_SEPARATOR,
           'table-level|tl=i' => \$TABLE_LEVEL,
           'ignore-breaks|ibr!' => sub { $SPLIT_AT_LINE_BREAKS = ! $_[1] },
           'sort-by-line|sl!' => \$REORDER_BY_LINE,
           'output-by-line|by-line|ol!' =>
           sub { $REORDER_BY_LINE = $REPEAT_SINGLE_LINE = $_[1] },
           'show-heading|h!' =>
           sub { add_rm_field PRE_TABLE_HEADING, $_[1] },
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
           'show-same-entry-text-before-link|entry-before|eb!' =>
           sub { add_rm_field SAME_ENTRY_TEXT_BEFORE_LINK, $_[1] },
           'show-same-entry-text-after-link|entry-after|ea!' =>
           sub { add_rm_field SAME_ENTRY_TEXT_AFTER_LINK, $_[1] },
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


# NB: this implementation matches plinks (or did at one point).
sub get_raw_text ( @ ) {
  my (@nodes) = @_;
  @nodes = grep defined, @nodes;
  return '' unless @nodes;
  @nodes = map $_->clone, @nodes;
  my $text = join '', map(($_->deobjectify_text() || $_->as_text), @nodes);
  $text;
}


# NB: this implementation matches plinks (or did at one point).
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


# NB: this implementation matches plinks (or did at one point).
sub get_in_between_nodes ( $$ ) {
  my ($from, $to) = @_;
  my @fparents = ($from, $from->lineage);
  my @tparents = ($to, $to->lineage);
  $fparents[-1] == $tparents[-1] or return ();  # not same root -> span is ()
  pop(@fparents), pop(@tparents)
    while @fparents and @tparents and $fparents[-1] == $tparents[-1];
  my $ftop = pop(@fparents);
  my $ttop = pop(@tparents);
  $ftop or $ttop or return ();  # same node -> span is ()
  if ($ftop and $ttop) {
      $ftop->parent == $ttop->parent or croak;  # inconsistent lineage -> error
      $ftop->pindex >= $ttop->pindex
        and return ();  # nodes are in reverse order -> span is ()
  }
  my @span;
  push @span, $_->right for @fparents;
  if (! $ftop) {
    push @span, $ttop->left;
  } elsif (! $ttop) {
    push @span, $ftop->right;
  } else {
    push @span,
      @{$ftop->parent->content}[($ftop->pindex+1)..($ttop->pindex-1)];
  }
  push @span, $_->left for reverse @tparents;
  return @span;
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


# first look at <a ...> tags inside <table ...> tags
printf STDERR "    %-67s ", "Traversing <a> and <table> tags..." if $VERBOSITY;
my (@links, %links, @tables, %tables);
for my $tag ($tree->look_down(_tag => 'a')) {
    defined $tag->{href} or next;
    my $table_tag = $tag->look_up(_tag => 'table') or next;
    # limit by $TABLE_LEVEL here if set
    defined $TABLE_LEVEL and get_table_level($tag) != $TABLE_LEVEL and next;

    if (! exists $tables{$table_tag}) {
      push @tables, +{ tag => $table_tag, links => [] };
      $tables{$table_tag} = $tables[-1];
    }
    my $table = $tables{$table_tag} or croak;
    my $link = { tag => $tag, href => $tag->attr('href'), table => $table };
    push @links, $link;
    $links{$tag} = $link;
    push @{ $table->{links} }, $link;
}
print STDERR "done.\n" if $VERBOSITY;

if (@tables) {
  printf STDERR "    %-67s ", "Building tables..." if $VERBOSITY;
  for my $table (@tables) {
    my @rows = $table->{tag}->content_list;
    @rows == 1 and $rows[0]->tag eq 'tbody' and @rows = $rows[0]->content_list;
    @rows = grep $_->tag eq 'tr', @rows;

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
    $table->{columns} = scalar @{$cells[0]};

    for my $r (0..($table->{rows}-1)) {
      my $n0 = $table->{columns};
      my $nR = @{$cells[$r]};
      $nR < $n0 and warn("warning: too few cells ($nR < $n0) in row $r" .
                         " (near @{[$cells[$r][-1]->as_HTML]})");
      $nR > $n0 and warn("warning: too many cells ($nR > $n0) in row $r" .
                         " (near @{[$cells[$r][-1]->as_HTML]})");
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

if (has_field SAME_ENTRY_TEXT_BEFORE_LINK) {
  printf STDERR "    %-67s ", "Extracting text in the same entry before link..." if $VERBOSITY;
  for my $link (@links) {
    my $line = $link->{+CELL_LINE_NUMBER} if $SPLIT_AT_LINE_BREAKS;
    my ($text, $from, $to) = '';
    ($from, $to) = get_line_edges $link->{cell}, $line
      and $text = get_text get_in_between_nodes $from, $link->{tag};
    $link->{+SAME_ENTRY_TEXT_BEFORE_LINK} = $text;
  }
  print STDERR "done.\n" if $VERBOSITY;
}

if (has_field SAME_ENTRY_TEXT_AFTER_LINK) {
  printf STDERR "    %-67s ", "Extracting text in the same entry after link..." if $VERBOSITY;
  for my $link (@links) {
    my $line = $link->{+CELL_LINE_NUMBER} if $SPLIT_AT_LINE_BREAKS;
    my ($text, $from, $to) = '';
    ($from, $to) = get_line_edges $link->{cell}, $line
      and $text = get_text get_in_between_nodes $link->{tag}, $to;
    $link->{+SAME_ENTRY_TEXT_AFTER_LINK} = $text;
  }
  print STDERR "done.\n" if $VERBOSITY;
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

if ($BASE_URI) {
    $_->{href_abs} = absolute_uri($_->{href}, $BASE_URI) for @links;
    push @fields, 'href_abs';
} else {
    push @fields, 'href';
}

printf STDERR "    %-67s ", "Producing output..." if $VERBOSITY;
print join("\t", @$_{@fields}) . "\n" for @links;
print STDERR "done.\n" if $VERBOSITY;
