#!/usr/bin/perl
# Show all links in a given page (file).
use warnings;
use strict;

use HTML::LinkExtor;

$| = 1;

my @pages;
my $build_links = HTML::LinkExtor->new(
    sub {
      my($tag, %attr) = @_;
      return if lc $tag ne 'a';  # only <a ...> tags
      push @pages, $attr{href} if exists $attr{href};
    });

@ARGV == 1 or die "Usage: $0 {FILE}\n";
$build_links->parse_file($ARGV[0]);

print "$_\n" for @pages;
