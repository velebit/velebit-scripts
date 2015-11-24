#!/usr/bin/perl
use warnings;
use strict;

use Cwd qw( getcwd );
use File::Spec qw( splitpath catpath splitdir );
use Getopt::Long;

# ----------------------------------------------------------------------

our $PRINT_SHORT_NAME;
our $REPLACE_ANY_PREFIX = 1;
our $TWO_DIGIT_NUMBERS;
my @EXTRA_STRIPPED_PREFIXES;
my @EXTRA_STRIPPED_STRINGS;
my @EXTRA_REPLACEMENTS;
my $SHORT_PREFIX;
my $FALLBACK_PREFIX;

sub add_replacement ( $ ) {
  my ($string) = @_;
  my ($regex, $replacement);
  ($regex, $replacement) = ($string =~ /^(.*)=>\s*(.*?)$/)
    or ($regex, $replacement) = ($string =~ /^(.*)=\s*(.*?)$/)
      or die "Could not parse replacement string '$string'";
  $regex =~ s/\s+$//s;
  $regex = qr/$regex/i;
  push @EXTRA_REPLACEMENTS, [ $regex, $replacement ];
}

sub from_file ( $$ ) {
  my ($file, $action) = @_;
  open my $IN, '<', $file or die "open($file): $!";
  local $_;
  while (<$IN>) {
    /^\#/ and next;
    s/^\s+//s;
    s/\s+$//s;
    length($_) or next;
    $action->($_);
  }
}

GetOptions('print-short-name|short-name|ps!' => \$PRINT_SHORT_NAME,
	   'replace-any-prefix!' => \$REPLACE_ANY_PREFIX,
	   'strip-prefix|sp=s' => \@EXTRA_STRIPPED_PREFIXES,
	   'strip-prefix-from-file|spf=s' =>
	     sub { from_file($_[1],
			     sub { push @EXTRA_STRIPPED_PREFIXES, $_[0]; }); },
	   'strip-string|ss=s' => \@EXTRA_STRIPPED_STRINGS,
	   'strip-string-from-file|ssf=s' =>
	     sub { from_file($_[1],
			     sub { push @EXTRA_STRIPPED_STRINGS, $_[0]; }); },
	   'replace|r=s' => sub { add_replacement($_[1]); },
	   'replace-from-file|rf=s' =>
	     sub { from_file($_[1], \&add_replacement); },
	   'auto-prefix=s' => \$SHORT_PREFIX,
	   'fallback-prefix=s' => \$FALLBACK_PREFIX,
	   'prefix=s' => sub { $SHORT_PREFIX = $FALLBACK_PREFIX = $_[1] },
	   'two-digit-numbers:i' => \$TWO_DIGIT_NUMBERS,
          ) or die "Usage: $0 [--ps | [other options] [list_files...]]\n";

# ----------------------------------------------------------------------


@EXTRA_STRIPPED_PREFIXES = qw( 14P10 KC15 15KC KC07 )
  unless @EXTRA_STRIPPED_PREFIXES;

@EXTRA_REPLACEMENTS = ( # Rain Dance 2014 orchestra track numbers
		       [ qr/^RD08 (?=.*Mister.*Hare)/i, 'RD2.2_' ],
		       [ qr/^RD09 (?=.*Old.*Age)/i, 'RD2.3_' ],
		       [ qr/^RD10 (?=.*Will.*Survive)/i, 'RD2.4_' ],
		       [ qr/^RD11 (?=.*Hail.*Tau)/i, 'RD3.1_' ],
		       # Kids' Court 2015 sub-track ordering
		       [ qr/^KC24_(?=.*Pulv.*Intro)/i, 'KC24.1_' ],
		       [ qr/^KC24_(?=.*Pulv.*Coda)/i, 'KC24.2_' ],
		       [ qr/^KC44_?(?=.*Story.*Dahs)/i, 'KC44.2_' ],
		       [ qr/^KC44_?(?=.*Story.*End)/i, 'KC44.3_' ],
		      ) unless @EXTRA_REPLACEMENTS;

my $short_name_suffix = '';
my @wd_elements = split(m!/!, getcwd);
while (@wd_elements) {
  $wd_elements[-1] =~ /^download|^scripts/
    and pop(@wd_elements), next;
  $wd_elements[-1] =~ /^audition/
    and pop(@wd_elements), $short_name_suffix = "_aud$short_name_suffix", next;
  last;
}
my $short_name = $wd_elements[-1];
$short_name =~ s/[\[\]]+//g;
$short_name =~ s/(?<!\S)(\w[A-Z0-9]*)/[$1]/g;
$short_name =~ s/^/\]/;
$short_name =~ s/$/\[/;
$short_name =~ s/\].*?\[//g;
$short_name =~ /[\[\]]/ and die "bad short name generated: '$short_name'\n ";
$short_name .= $short_name_suffix;

if ($PRINT_SHORT_NAME) {
  print "$short_name\n";
  exit 0;
}

$SHORT_PREFIX = $short_name unless defined $SHORT_PREFIX;

# ----------------------------------------------------------------------

sub canonicalize_file ( $ ) {
  my ($file) = @_;
  my $stage = -1;
  $file =~ s/\.mp3$//i;
  $file =~ s/^\Q$_\E[-_]// for @EXTRA_STRIPPED_PREFIXES;
  $file =~ s/\Q$_\E// for @EXTRA_STRIPPED_STRINGS;
  $file =~ s/^[^\.]*?(?=\d)/${SHORT_PREFIX}/ if $REPLACE_ANY_PREFIX;
  $file =~ s/^(\Q${SHORT_PREFIX}\E\d+)[-_](\d+)/$1.$2/;
  $file =~ s/(\d+)/sprintf "%02d", $1/ge
    if defined $TWO_DIGIT_NUMBERS;
  my $replaced;
  ($file =~ s/$_->[0]/qq(qq($_->[1]))/ee and $replaced = 1)
    for @EXTRA_REPLACEMENTS;
  if (! $replaced and defined $FALLBACK_PREFIX and length $FALLBACK_PREFIX) {
    $file = $FALLBACK_PREFIX . $file;
  }
  $file . '.mp3';
}

sub canonicalize ( $ ) {
  my ($path) = @_;
  my (@path) = split m!/+!, $path;
  $path[-1] = canonicalize_file $path[-1];
  join '/', @path;
}

# ----------------------------------------------------------------------

my @output;
while (<>) {
  chomp;
  my ($in, $out) = split /=/, $_, 2;
  defined $out or die "bad input format: '$_'";

  my $fixed = canonicalize $out;
  print "$in=$fixed\n";
}
