#!/usr/bin/perl
use warnings;
use strict;

use HTML::TreeBuilder;

# ----------------------------------------------------------------------

sub Usage ( @ ) {
  die join "\n", @_, <<"EndOfMessage";
Usage: $0 {HTML_FILE} {TABLE_LABEL} [+{TABLE_INDEX}] {COLUMN_LABEL}
EndOfMessage
  exit 1;  # backstop
}


our $VERBOSITY = 0;

while (@ARGV and $ARGV[0] =~ /^-/) {
  $ARGV[0] eq '-v' and ++$VERBOSITY, shift(@ARGV), next;
  die "Unknown argument '$ARGV[0]'";
}
my $file      = shift @ARGV or die "too few args";
my $tbl_label = shift @ARGV or die "too few args";
my $tbl_idx   = 0;
$tbl_idx      = 0 + shift @ARGV if @ARGV and $ARGV[0] =~ /^\+\d+$/;
my $col_label = shift @ARGV or die "too few args";
@ARGV and die "too many args";

# ----------------------------------------------------------------------

sub slurp ( $ ) {
  my ($file) = @_;
  open my $FH, '<', $file or die "open($file): $!";
  local ($/) = undef;
  my $d = scalar <$FH>;
  $d;
}

# ----------------------------------------------------------------------

{
  printf STDERR "%-72s", "  Reading page data... " if $VERBOSITY;
  my $content = slurp $file;
  print STDERR "done.\n" if $VERBOSITY;

  printf STDERR "%-72s", "  Parsing data into a tree... " if $VERBOSITY;
  my $tree = HTML::TreeBuilder->new;
  $tree->parse_content($content);
  print STDERR "done.\n" if $VERBOSITY;

  printf STDERR "%-72s", "  Finding table... " if $VERBOSITY;
  my @matches = $tree->look_down(_tag => 'p',
				  sub { $_[0]->as_text =~ /$tbl_label/ });
  @matches      or die "No results found";
  @matches == 1 or die "Multiple results found";

  my $node = $matches[0];
  my $index = $tbl_idx;
  my $table;
  {
  TABLE:
    while (1) {
      my @tables = $node->look_down(_tag => 'table');
      @tables and $index < @tables
	and $table = $tables[$index], last TABLE;
      $index -= @tables;
      while (1) {
	my $rnode;
	$node->right and $node = $node->right, next TABLE;
	$node = $node->parent or last TABLE;
      }
    }
    $table or die;
    #$table->dump;
  }
  print STDERR "done.\n" if $VERBOSITY;

  printf STDERR "%-72s", "  Processing table... " if $VERBOSITY;
  my @rows = $table->content_list;
  @rows == 1 and $rows[0]->tag eq 'tbody' and @rows = $rows[0]->content_list;
  @rows = grep $_->tag eq 'tr', @rows;
  @rows > 2 or die "short table (@{[scalar @rows]} rows)";

  my @cells;
  my @in_rowspan = map [], 1..@rows;
  for my $r (0..$#rows) {
    my $c = -1;
    for my $cell ($rows[$r]->content_list) {
      $cell->tag =~ /^t[hd]$/ or die "unexpected tag @{[$cell->tag]}";
      ++$c while $in_rowspan[$r][$c+1];
      for (0..(($cell->attr('colspan') || 1)-1)) {
	++$c;
	$in_rowspan[$r][$c]
	  and die "row span/column span intersection";
	$cells[$r][$c] = $cell;
	$cells[$r+$_][$c] = $cell, ++$in_rowspan[$r+$_][$c]
	  for 1..(($cell->attr('rowspan') || 1)-1);
      }
    }
    ++$c while $c < $#{$in_rowspan[$r]} && $in_rowspan[$r][$c+1];
    $c < $#{$cells[$r]} and die;
    $c > $#{$cells[$r]} and warn "short line";
    $#{$cells[$r]} = $c;
  }
  for my $r (1..$#rows) {
    my $n0 = @{$cells[0]};
    my $nR = @{$cells[$r]};
    $nR < $n0 and warn("warning: too few cells ($nR < $n0) in row $r" .
		       " of table $tbl_idx for '$tbl_label'");
    $nR > $n0 and warn("warning: too many cells ($nR > $n0) in row $r" .
		       " of table $tbl_idx for '$tbl_label'");
  }
  print STDERR "done.\n" if $VERBOSITY;

  printf STDERR "%-72s", "  Finding column... " if $VERBOSITY;
  @matches = grep $cells[0][$_] && $cells[0][$_]->as_text =~ /$col_label/,
    0..$#{$cells[0]};
  @matches      or die "No results found";
  @matches == 1 or die "Multiple results found";

  my $col_idx = $matches[0];
  my @urls = map $_->attr('href'),
    map $_->look_down(_tag => 'a', href => qr/./),
      grep defined, map $cells[$_][$col_idx], 0..$#cells;
  print "$_\n" for @urls;
  print STDERR "done.\n" if $VERBOSITY;
}
