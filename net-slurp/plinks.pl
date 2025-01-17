#!/usr/bin/perl
# Show all links in a given page (file).
# print-table-links and extract-column-links share some code via cut+paste.
use warnings;
use strict;
use open ':std', ':encoding(UTF-8)';

use Getopt::Long;
use HTML::TreeBuilder;
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
Data selection options:
  --table-level LEVEL   (-tl)  Only show links within LEVEL nested tables.
  --not-in-table               Shorthand for `--table-level 0'.
  --merge-links         (-ml)  Treat adjacent links to same URI as one link.
Output options (extra fields printed before URI, separated by tabs):
  --show-heading         (-h)  Show text of preceding <h#> or <title> tag.
  --show-heading1       (-h1)  Show text of preceding <h1> tag.
  --show-heading2       (-h2)  Show text of preceding <h2> tag.
  --show-bold-or-heading
                        (-hb)  Show text of preceding <strong>, <h#> or
                               <title> tag, with some heuristic filtering.
  --show-parent-text    (-pt)  Show text for the link's parent node.
  --show-previous-line-text
                       (-plt)  Show text for the line preceding the link.
  --show-line-text      (-lt)  Show text for the line with the link.
  --show-less-indented [MAX_LINES]
                        (-li)  Show text for preceding lines that are less
                               indented than the line with the link.  Shows at
                               most MAX_LINES lines, if specified.
  --show-line-links     (-ll)  Show the *number* of links on the same line.
  --show-line-before-link
                        (-lb)  Show text on the same line up to first link.
  --show-line-after-link
                        (-la)  Show text on the same line following last link.
  --show-text            (-t)  Show text of the link itself.
EndOfMessage
  exit 1;  # backstop
}


use constant HEADING => 'heading';
use constant HEADING1 => 'heading1';
use constant HEADING2 => 'heading2';
use constant STRONG_OR_HEADING => 'str_head';
use constant PARENT1_TEXT => 'parent1_text';
use constant PRECEDING_LESS_INDENTED_TEXT => 'preceding_less_indented_text';
use constant PREVIOUS_LINE_TEXT => 'prev_line_text';
use constant SAME_LINE_TEXT => 'same_line_text';
use constant SAME_LINE_NUM_LINKS => 'same_line_num_links';
use constant SAME_LINE_BEFORE_LINK => 'same_line_before';
use constant SAME_LINE_AFTER_LINK => 'same_line_after';
use constant TEXT => 'text';


our @fields;

# NB: this implementation matches print-table-links (or did at one point).
sub add_rm_field ( $$ ) {
  my ($name, $add) = @_;
  if ($add) {
    push @fields, $name;
  } else {
    @fields = grep $_ ne $name, @fields;
  }
}

# NB: this implementation matches print-table-links (or did at one point).
sub has_field ( $ ) {
  my ($name) = @_;
  scalar grep $_ eq $name, @fields;
}

# NB: this implementation matches print-table-links (or did at one point).
sub unique ( @ ) {
  my (%seen);
  grep !($seen{$_}++), @_;
}

# NB: this implementation matches print-table-links (or did at one point).
sub get_matching_fields ( $ ) {
  my ($prefix) = @_;
  unique grep $_ =~ qr/^\Q$prefix\E/, @fields;
}

# NB: this implementation matches print-table-links (or did at one point).
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

our $WHITESPACE_MAX_IGNORED = 1;
our $WHITESPACE_DELTA_IGNORED = 0;

our $PRECEDING_LESS_INDENTED_TEXT_MAX_LINES = 999;

GetOptions('verbose|v+' => \$VERBOSITY,
           'base=s' => \$BASE_URI,
           'ascii-text|7!' => \$TEXT_AS_ASCII,
           'table-level|tl=i' => \$TABLE_LEVEL,
           'not-in-table' => sub { $TABLE_LEVEL = 0 },
           'merge-links|ml!' => \$MERGE_LINKS,
           'show-heading|h!' =>
           sub { add_rm_field HEADING, $_[1] },
           'show-heading1|h1!' =>
           sub { add_rm_field HEADING1, $_[1] },
           'show-heading2|h2!' =>
           sub { add_rm_field HEADING2, $_[1] },
           'show-bold-or-heading|hb!' =>
           sub { add_rm_field STRONG_OR_HEADING, $_[1] },
           'show-parent-text|pt!' =>
           sub { add_rm_field PARENT1_TEXT, $_[1] },
           'show-previous-line-text|plt!' =>
           sub { add_rm_field PREVIOUS_LINE_TEXT, $_[1] },
           'show-line-text|lt!' =>
           sub { add_rm_field SAME_LINE_TEXT, $_[1] },
           'show-less-indented|li:999' =>
           sub {
             add_rm_field PRECEDING_LESS_INDENTED_TEXT, ($_[1] > 0);
             $PRECEDING_LESS_INDENTED_TEXT_MAX_LINES = $_[1];
           },
           'show-line-links|ll!' =>
           sub { add_rm_field SAME_LINE_NUM_LINKS, $_[1] },
           'show-line-before-link|lb!' =>
           sub { add_rm_field SAME_LINE_BEFORE_LINK, $_[1] },
           'show-line-after-link|la!' =>
           sub { add_rm_field SAME_LINE_AFTER_LINK, $_[1] },
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


# NB: this implementation matches p-t-l/e-c-l (or did at one point).
sub get_raw_text ( @ ) {
  my (@nodes) = @_;
  @nodes = grep defined, @nodes;
  return '' unless @nodes;
  @nodes = map $_->clone, @nodes;
  my $text = join '', map(($_->deobjectify_text() || $_->as_text), @nodes);
  $text;
}


# NB: this implementation matches p-t-l/e-c-l (or did at one point).
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
  $text =~ /\S/ or return undef;
  my $whitespace = (($text =~ /^( +)/) ? length $1 : 0);
  ($whitespace > $WHITESPACE_MAX_IGNORED) ? $whitespace : 0;
}


# NB: this implementation matches p-t-l/e-c-l (or did at one point).
sub get_divergent_lineage ( $$ ) {
  my ($from, $to) = @_;
  croak if !defined $from or !defined $to;
  my @fparents = ($from, $from->lineage);
  my @tparents = ($to, $to->lineage);
  pop(@fparents), pop(@tparents)
    while @fparents and @tparents and $fparents[-1] == $tparents[-1];
  return (\@fparents, \@tparents);
}


# NB: this implementation matches p-t-l/e-c-l (or did at one point).
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


# NB: this implementation matches print-table-links (or did at one point).
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


sub next_leftward ( $ ) {
  my ($node) = @_;
  my $left;
  while (1) {
    $left = $node->left and return $left;
    $node = $node->parent or return;
  }
}

sub next_rightward ( $ ) {
  my ($node) = @_;
  my $right;
  while (1) {
    $right = $node->right and return $right;
    $node = $node->parent or return;
  }
}


sub look_leftward_down ( $@ ) {
  my ($node, @terms) = @_;
  while (1) {
    $node = next_leftward($node) or return;
    my @matches = $node->look_down(@terms);
    return $matches[-1] if @matches;
  }
}

sub look_rightward_down ( $@ ) {
  my ($node, @terms) = @_;
  while (1) {
    $node = next_rightward($node) or return;
    my @matches = $node->look_down(@terms);
    return $matches[0] if @matches;
  }
}


# NB: this implementation matches extract-column-links (or did at one point).
sub look_leftward_siblings_down ( $@ ) {
  my ($node, @terms) = @_;
  while (1) {
    $node = $node->left or return;
    my @matches = $node->look_down(@terms);
    return $matches[-1] if @matches;
  }
}

# NB: this implementation matches extract-column-links (or did at one point).
sub look_rightward_siblings_down ( $@ ) {
  my ($node, @terms) = @_;
  while (1) {
    $node = $node->right or return;
    my @matches = $node->look_down(@terms);
    return $matches[0] if @matches;
  }
}


# NB: this implementation matches extract-column-links (or did at one point).
sub get_same_line_siblings ( $ ) {
  my ($node) = @_;
  return () unless $node;
  my $start = look_leftward_siblings_down($node, _tag => qr/^(?:br|hr)$/);
  my $end = look_rightward_siblings_down($node, _tag => qr/^(?:br|hr)$/);
  if ($start and $end) {
    # NB: $start and $end can't be the same node
    return (get_in_between_nodes($start, $end), $end);   # exclude $start
  } elsif ($start) {
    return (get_in_between_nodes($start, $node->parent));    # exclude $start
  } elsif ($end) {
    return (get_in_between_nodes($node->parent, $end), $end);
  } else {
    return $node->parent->content_list;
  }
}


sub get_previous_line_siblings ( $ ) {
  my ($node) = @_;
  return () unless $node;
  my $end = look_leftward_siblings_down($node, _tag => qr/^(?:br|hr)$/)
    or return ();
  my $start = look_leftward_siblings_down($end, _tag => qr/^(?:br|hr)$/);
  # NB: $start and $end can't be the same node
  return (get_in_between_nodes($start || $node->parent, $end), $end);
}


sub get_preceding_less_indented_lines_text ( $;$ ) {
  my ($node, $max_lines) = @_;
  return '' unless $node;
  my $indent = 0;
  {
    my @current = get_same_line_siblings($node);
    $indent = get_leading_whitespace_amount(@current);
    defined $indent or $indent = 0;
    $node = $current[0] if @current;
  }
  my @lines;
  {
  LINE:
    while ($node and $indent > $WHITESPACE_DELTA_IGNORED) {
      my @previous = get_previous_line_siblings($node)
        or last LINE;
      $node = $previous[0];
      my $previous_indent = get_leading_whitespace_amount(@previous);
      defined $previous_indent or next LINE;
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


sub get_same_line_before_link ( $ ) {
  my ($node) = @_;
  my @fragment;
  for my $n (get_same_line_siblings($node)) {
    my @matches = $n->look_down(_tag => 'a');
    if (@matches) {
      push @fragment, get_in_between_nodes($n, $matches[0]);
      last;
    }
    push @fragment, $n;
  }
  return @fragment;
}

sub get_same_line_after_link ( $ ) {
  my ($node) = @_;
  my @fragment;
  for my $n (reverse get_same_line_siblings($node)) {
    my @matches = $n->look_down(_tag => 'a');
    if (@matches) {
      unshift @fragment, get_in_between_nodes($matches[-1], $n);
      last;
    }
    unshift @fragment, $n;
  }
  return @fragment;
}


# NB: this implementation matches print-table-links (or did at one point).
sub nonempty ( @ ) {
  grep(($_->tag ne '~text' or $_->attr('text') !~ /^[\s\xA0]+$/s), @_);
}


# NB: this implementation matches print-table-links (or did at one point).
sub get_markup_headings ( $ ) {
  my ($node) = @_;
  return unless $node;
  $node->look_down(_tag => qr/^(?:title|h\d)$/);
}

# build_get_level_headings('hN') returns a sub ref that extracts hN headings
# NB: this implementation matches print-table-links (or did at one point).
sub build_get_level_headings ( $ ) {
  my ($tag) = @_;
  $tag =~ /^h\d$/ or die "Unexpected heading tag '$tag'";
  sub {
    my ($node) = @_;
    return unless $node;
    $node->look_down(_tag => qr/^(?:$tag)$/);
  };
}

# NB: this implementation matches print-table-links (or did at one point).
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

# NB: this implementation matches print-table-links (or did at one point).
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

# NB: this implementation matches print-table-links (or did at one point).
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

# NB: this implementation matches print-table-links (or did at one point).
sub find_heading ( $$ ) {
  my ($node, $get_headings) = @_;
  my (@headings) = $get_headings->($node);
  # For our own headings, we pick the first, but don't cache it.
  @headings and return $headings[0];

  traverse_to_heading($node, $get_headings);
}

# NB: this implementation matches print-table-links (or did at one point).
sub find_heading_text ( $$ ) {
  my ($node, $get_headings) = @_;
  my ($heading) = find_heading($node, $get_headings);
  $heading ? get_text($heading) : '';
}

# NB: this implementation matches print-table-links (or did at one point).
sub get_table_level ( $ ) {
  my ($node) = @_;
  scalar(@{[$node->look_up(_tag => 'table')]});
}

# NB: this implementation matches print-table-links (or did at one point).
sub absolute_uri ( $;$ ) {
    my ($uri, $base) = @_;
    $uri = URI->new_abs($uri, $base) unless $uri =~ /^#/;
    "$uri";
}


# only look at <a ...> tags
printf STDERR "    %-67s ", "Traversing <a> tags..." if $VERBOSITY;
my @links = grep defined $_->{href},
  map +{ tag => $_, href => $_->attr('href') }, $tree->look_down(_tag => 'a');
print STDERR "done.\n" if $VERBOSITY;

if ($MERGE_LINKS) {
  printf STDERR "    %-67s ", "Merging <a> tags..." if $VERBOSITY;
  my $prev;
  for my $link (@links) {
    if ($prev and $prev->{href} eq $link->{href}) {
      # adjacent links to same URI, not sure if can merge
      try_merging_nodes($prev->{tag}, $link->{tag})
        and delete $link->{tag};
    }
    $prev = $link if exists $link->{tag};
  }
  @links = grep exists $_->{tag}, @links;
  print STDERR "done.\n" if $VERBOSITY;
}

if (defined $TABLE_LEVEL) {
  printf STDERR "    %-67s ", "Limiting by table level..." if $VERBOSITY;
  @links = grep get_table_level($_->{tag}) == $TABLE_LEVEL, @links;
  print STDERR "done.\n" if $VERBOSITY;
}

if (has_field HEADING) {
  printf STDERR "    %-67s ", "Extracting headings..." if $VERBOSITY;
  clear_headings_cache;
  my $get_headings = \&get_markup_headings;
  $_->{+HEADING} = find_heading_text($_->{tag}, $get_headings) for @links;
  print STDERR "done.\n" if $VERBOSITY;
}

for my $h ([HEADING1, 'h1'], [HEADING2, 'h2']) {
  my ($field, $tag) = @$h;
  if (has_field $field) {
    printf STDERR "    %-67s ", "Extracting $tag headings..." if $VERBOSITY;
    clear_headings_cache;
    my $get_headings = build_get_level_headings $tag;
    $_->{$field} = find_heading_text($_->{tag}, $get_headings) for @links;
    print STDERR "done.\n" if $VERBOSITY;
  }
}

if (has_field STRONG_OR_HEADING) {
  printf STDERR "    %-67s ", "Extracting heading/strongs..." if $VERBOSITY;
  clear_headings_cache;
  my $get_headings = \&get_display_headings;
  $_->{+STRONG_OR_HEADING} = find_heading_text($_->{tag}, $get_headings) for @links;
  print STDERR "done.\n" if $VERBOSITY;
}

if (has_field PARENT1_TEXT) {
  printf STDERR "    %-67s ", "Extracting parent text..." if $VERBOSITY;
  $_->{+PARENT1_TEXT} = get_text($_->{tag}->parent) for @links;
  print STDERR "done.\n" if $VERBOSITY;
}

if (has_field PRECEDING_LESS_INDENTED_TEXT) {
  printf STDERR "    %-67s ", "Extracting text on the less indented line(s) in parent..." if $VERBOSITY;
  $_->{+PRECEDING_LESS_INDENTED_TEXT} =
    get_preceding_less_indented_lines_text(
      $_->{tag}, $PRECEDING_LESS_INDENTED_TEXT_MAX_LINES)
    for @links;
  print STDERR "done.\n" if $VERBOSITY;
}

if (has_field PREVIOUS_LINE_TEXT) {
  printf STDERR "    %-67s ", "Extracting text on the previous line..." if $VERBOSITY;
  $_->{+PREVIOUS_LINE_TEXT} = get_text(get_previous_line_siblings($_->{tag})) for @links;
  print STDERR "done.\n" if $VERBOSITY;
}

if (has_field SAME_LINE_TEXT) {
  printf STDERR "    %-67s ", "Extracting text on the same line..." if $VERBOSITY;
  $_->{+SAME_LINE_TEXT} = get_text(get_same_line_siblings($_->{tag})) for @links;
  print STDERR "done.\n" if $VERBOSITY;
}

if (has_field SAME_LINE_NUM_LINKS) {
  printf STDERR "    %-67s ", "Extracting # links on the same line..." if $VERBOSITY;
  $_->{+SAME_LINE_NUM_LINKS} = get_num_links(get_same_line_siblings($_->{tag})) for @links;
  print STDERR "done.\n" if $VERBOSITY;
}

if (has_field SAME_LINE_BEFORE_LINK) {
  printf STDERR "    %-67s ", "Extracting text before link..." if $VERBOSITY;
  $_->{+SAME_LINE_BEFORE_LINK} = get_text(get_same_line_before_link($_->{tag})) for @links;
  print STDERR "done.\n" if $VERBOSITY;
}

if (has_field SAME_LINE_AFTER_LINK) {
  printf STDERR "    %-67s ", "Extracting text after link..." if $VERBOSITY;
  $_->{+SAME_LINE_AFTER_LINK} = get_text(get_same_line_after_link($_->{tag})) for @links;
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
