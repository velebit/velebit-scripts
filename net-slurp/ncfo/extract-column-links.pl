#!/usr/bin/perl
use warnings;
use strict;

use HTML::TreeBuilder;
use Getopt::Long;
use Carp qw( carp croak );

# ----------------------------------------------------------------------

sub Usage ( @ ) {
  die join "\n\n", @_, <<"EndOfMessage";
Usage: $0 [options | {HTML_FILE} {TABLE_LABEL} [+{TABLE_INDEX}] {COLUMN_LABEL}]
Global options:
  --file HTML_FILE       (-f)  The name of the input HTML file.
  --verbose              (-v)  Display additional output messages.
  --print-links          (-l)  Prefix URLs with their link text and a tab.
Repeatable options:
  --message TEXT         (-m)  Print a message before processing the table.
  --table TABLE_LABEL    (-t)  The label in HTML before the desired table.
  --index TABLE_INDEX    (-i)  The index offset to the desired table (e.g. to
                               get act 2).  [default: 0]
  --column COLUMN_LABEL  (-c)  The label of the desired column in the HTML
                               table.
  --output OUTPUT_FILE   (-o)  Write output to the specified file.
  --go                   (-G)  Commit the preceding options so they can be
                               specified several times.

Arguments (the old way of specifying what to do):
  HTML_FILE:     The name of the input HTML file.
  TABLE_LABEL:   The label in HTML before the desired table.
  TABLE_INDEX:   The index offset to the desired table (e.g. to get act 2).
  COLUMN_LABEL:  The label of the desired column in the HTML table.
EndOfMessage
  exit 1;  # backstop
}


our $INPUT_FILE;
sub set_input_file ( $ ) {
  defined $INPUT_FILE and warn("More than one input file specified." .
			       "  Ignoring '$INPUT_FILE'.\n");
  ($INPUT_FILE) = @_;
}

my @item_list;
my $item = {};

sub commit () {
  if (defined $item->{tbl_label} and defined $item->{col_label}) {
    push @item_list, $item;
  } else {
    print STDERR "Warning: item incomplete; skipped!\n";
  }
  $item = {};
}

sub set_output_file ( $ ) {
  my $auto_commit = !! %$item;
  defined $item->{output} and warn("More than one output file specified." .
				   "  Ignoring '$item->{output}'.\n");
  ($item->{output}) = @_;

  commit if $auto_commit;
}

sub set_msg ( $ ) {
  defined $item->{msg} and warn("Multiple messages specified." .
				"  Ignoring '$item->{msg}'.\n");
  ($item->{msg}) = @_;
}
sub set_tbl_label ( $ ) {
  defined $item->{tbl_label} and warn("Multiple table labels specified." .
				      "  Ignoring '$item->{tbl_label}'.\n");
  ($item->{tbl_label}) = @_;
}
sub set_tbl_idx ( $ ) {
  defined $item->{tbl_idx} and warn
("Multiple table indices specified." .
				    "  Ignoring '$item->{tbl_idx}'.\n");
  ($item->{tbl_idx}) = @_;
}
sub set_col_label ( $ ) {
  defined $item->{col_label} and warn("Multiple table labels specified." .
				      "  Ignoring '$item->{col_label}'.\n");
  ($item->{col_label}) = @_;
}

our $VERBOSITY = 0;
our $PRINT_LINK_TEXT;

GetOptions('file|f=s' => sub { set_input_file $_[1] },
	   'verbose|v+' => \$VERBOSITY,
	   'print-links|links|l!' => \$PRINT_LINK_TEXT,
	   'message|m=s' => sub { set_msg $_[1] },
	   'table|t=s' => sub { set_tbl_label $_[1] },
	   'index|i=i' => sub { set_tbl_label $_[1] },
	   'column|c=s' => sub { set_col_label $_[1] },
	   'output|o=s' => sub { set_output_file $_[1] },
	   'go|G' => sub { commit },
          ) or Usage;


sub must_be_defined ( $ ) {
  my ($value) = @_;
  defined $value or Usage "too few args";
  $value;
}


if (@ARGV and ! defined $INPUT_FILE) {
  set_input_file(shift @ARGV or Usage "too few args");
}
if (@ARGV) {
  set_tbl_label(shift @ARGV or Usage "too few args");
  set_tbl_idx(0 + shift @ARGV) if @ARGV and $ARGV[0] =~ /^\+\d+$/;
  set_col_label(must_be_defined shift @ARGV);
  commit;
}
@ARGV and Usage "too many args";
defined $INPUT_FILE or Usage "input file not specified";

# ----------------------------------------------------------------------

sub input_file_handle ( $ ) {
  my ($file) = @_;
  open my $fh, '<', $file or die "open(<$file): $!";
  $fh;
}

sub output_file_handle ( $ ) {
  my ($file) = @_;
  open my $fh, '>', $file or die "open(>$file): $!";
  $fh;
}

sub stdout_handle () {
  open my $fh, '>&', \*STDOUT or die "open(>&STDOUT): $!";
  $fh;
}

sub output_handle ( $ ) {
  my ($file) = @_;
  if (! defined $file or $file eq '' or $file eq '-') {
    return stdout_handle;
  } else {
    return output_file_handle $file;
  }
}

sub slurp_from_handle ( $ ) {
  my ($fh) = @_;
  local ($/) = undef;
  my $d = scalar <$fh>;
  $d;
}

sub clean ( $ ) {
  my ($text) = @_;
  $text =~ s/[\xA0\xC2]/ /sg;
  $text =~ s/^\s+//s;
  $text =~ s/\s+$//s;
  $text =~ s/\s+/ /sg;
  $text;
}

sub clean_text ( $ ) {
  my ($element) = @_;
  my $text = ref($element) ? $element->as_text : $element;
  clean($text);
}

# ----------------------------------------------------------------------

sub read_page ( $ ) {
  my ($handle) = @_;
  printf STDERR "    %-67s ", "Reading page data..." if $VERBOSITY;
  my $content = slurp_from_handle $handle;
  print STDERR "done.\n" if $VERBOSITY;

  printf STDERR "    %-67s ", "Parsing data into a tree..." if $VERBOSITY;
  my $tree = HTML::TreeBuilder->new;
  $tree->parse_content($content);
  print STDERR "done.\n" if $VERBOSITY;

  $tree;
}

sub extract ( $$$$$$ ) {
  my ($tree, $handle, $msg, $tbl_label, $tbl_idx, $col_label) = @_;

  print STDERR "$msg\n" if defined $msg and length $msg;

  printf STDERR "    %-67s ", "Finding table..." if $VERBOSITY;
  my @matches = $tree->look_down(_tag => 'p',
				  sub { clean_text($_[0]) =~ /$tbl_label/ });
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

  printf STDERR "    %-67s ", "Processing table..." if $VERBOSITY;
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

  printf STDERR "    %-67s ", "Finding column..." if $VERBOSITY;
  @matches = grep $cells[0][$_] && clean_text($cells[0][$_]) =~ /$col_label/,
    0..$#{$cells[0]};
  @matches      or die "No results found";
  @matches == 1 or die "Multiple results found";

  my $col_idx = $matches[0];
  my @links =
    map $_->look_down(_tag => 'a', href => qr/./),
      grep defined, map $cells[$_][$col_idx], 0..$#cells;
  for my $link (@links) {
    print $handle clean_text($link) . "\t" if $PRINT_LINK_TEXT;
    print $handle $link->attr('href') . "\n";
  }
  print STDERR "done.\n" if $VERBOSITY;
}


{
  my $tree = read_page input_file_handle $INPUT_FILE;
  for my $item (@item_list) {
    extract $tree, output_handle($item->{output}), $item->{msg},
      $item->{tbl_label}, ($item->{tbl_idx} || 0), $item->{col_label};
  }
}
