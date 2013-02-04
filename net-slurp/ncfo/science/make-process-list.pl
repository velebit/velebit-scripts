#!/usr/bin/perl
use warnings;
use strict;

############################################################

sub _add_prefix ( $$ ) { map $_[0] . $_, @{$_[1]}; }

sub curly_expand ( $ ) {
  my ($expr) = @_;
  my @parts = split /(\{.*?\})/, $expr;
  @parts > 1 or return $expr;
  my @opts = map([ /^\{(.*)\}$/ ? split(/,/, $1, -1) : $_ ],
		 grep length, @parts);

  my @results = @{ pop @opts };
  while (@opts) {
    @results = map _add_prefix($_, \@results), @{ pop @opts };
  }

  @results;
}

sub case_expand ( $ ) {
  my ($expr) = @_;
  $expr =~ s/(\w)/\[\u$1\l$1\]/ig;
  $expr;
}

############################################################

sub filename_only ( $ ) {
  my ($file) = @_;
  $file =~ s,^.*/,,;
  $file;
}

sub base_filename ( $ ) {
  my ($file) = @_;
  $file = filename_only $file;
  $file =~ s/^\d\d[-_ ]//;
  $file =~ s/^LT-//;
  $file =~ s/^(?:DH|AG|SH)_//;
  $file =~ s/\s/_/g;
  $file =~ s/_{2,}/_/g;
  $file;
}

sub uniform_filename ( $$$ ) {
  my ($idx, $auth, $file) = @_;
  my $base = base_filename $file;
  length($auth) ? "${idx}_${auth}_${base}" : "${idx}_${base}";
}

############################################################

sub flags ( $@ ) {
  my ($who, @flag_sets) = @_;
  my %flags;
  for my $f (@flag_sets) {
    %flags = (%flags, %$f);
    # need to do this here, not after the loop, or collisions cause problems:
    %flags = (%flags, %{$f->{'*'}})
      if exists $f->{'*'} and ref $f->{'*'};
    %flags = (%flags, %{$f->{$who}})
      if exists $f->{$who} and ref $f->{$who};
  }
  #delete $flags{$_} for @groups;
  \%flags;
}

sub matches ( $ ) {
  my ($flags) = @_;
  my $idx = $flags->{id};
  my @match_flags = grep length, @$flags{sort grep /^match/, keys %$flags};
  my @ignore_flags = grep length, @$flags{sort grep /^ignore/, keys %$flags};

  my $glob = join '*', 'mp3/', $flags->{name}, @match_flags, '.mp3';
  my @xglobs = map case_expand($_), map curly_expand($_), $glob;
  my @files = map glob($_), @xglobs;

  if (@ignore_flags) {
    if ($flags->{debug}) {
      print STDERR "+++ file matches for $glob +++\n";
      print STDERR "$_\n" for @files;
    }

    my $iglob = join '*', 'mp3/', $flags->{name}, @ignore_flags, '.mp3';
    my @ixglobs = map case_expand($_), map curly_expand($_), $iglob;
    my @ifiles = map glob($_), @ixglobs;

    if ($flags->{debug}) {
      print STDERR "--- ignore matches for $iglob ---\n";
      print STDERR "$_\n" for @ifiles;
    }

    my %ifiles = map $_ => 1, @ifiles;
    @files = grep !$ifiles{$_}, @files;
  }

  if ($flags->{debug}) {
    print STDERR "=== file results for $glob ===\n";
    print STDERR "$_\n" for @files;
  }

  @files;
}

sub find_files ( $@ ) {
  my ($who, @flag_sets) = @_;

  my $flags = flags $who, @flag_sets;
  my @files = matches $flags;
  return ($flags, $flags, \@files) if @files;

  my @fallback = @{$flags->{fallback}} if exists $flags->{fallback};
  for my $fbwho (@fallback) {
    my $fbflags = flags $fbwho, @flag_sets;
    @files = matches $fbflags;
    return ($flags, $fbflags, \@files) if @files;
  }

  my $showflags = flags 'show', @flag_sets;
  @files = matches $showflags;
  if (@files) {
    warn join("\n    ",
	      "*** No files found for $flags->{name}!  Possibly relevant:",
	      @files) . "\n";
  } else {
    warn "*** No files found for $flags->{name}, and nothing seems relevant\n";
  }
  ($flags, $showflags, []);
}

sub process ( $@ ) {
  my ($who, @flag_sets) = @_;
  my ($flags, $fbflags, $files) = find_files $who, @flag_sets;

  ! @$files and return;

  my $destdir = $flags->{destdir} if exists $flags->{destdir};
  if ((@$files > 1) and $destdir) {
    print STDERR ("--- WARNING: @{[scalar @$files]} files match $flags->{name}"
		  . " [copying all]\n");
    print STDERR "    $_\n" for @$files;
  } elsif ($flags->{display}) {
    print STDERR "--- Matches for $flags->{name}:\n";
    print STDERR "    $_\n" for @$files;
  }

  defined $destdir or return;

  for my $i (@$files) {
    my $n = base_filename $i;
    my $u = uniform_filename $flags->{id}, '', $n;
    my $d = "$destdir/$u";
    print "$i=$d\n";
  }
  1;
}

############################################################

my @group_info =
  ( show => { display => 1, no_copy => 1, no_auto => 1 },

    Kata => { match => '{kid,sop}' },
    Abbe => { match => 'alt' },
    bert => { match => '{bass,baritone}' },
  );
my %groups = @group_info;
my @groups = map $group_info[2*$_], 0..int($#group_info/2);
my @auto_groups = grep !($groups{$_}{no_auto}), @groups;

my @tracks =
  ( { id => '01',  name => 'Cetac{e,i}ans' },
    { id => '02',  name => 'Living*Light',
      bert => { match => 'bass_hi' } },
    { id => '03',  name => 'Tamar*Valley' },
    { id => '04',  name => 'Clouds',
      Kata => { match => 'kids_hi' } },
    { id => '05a', name => 'Sea*Fever*Intro' },
    { id => '05b', name => 'Sea*Fever',
      Kata => { match => 'hi' }, Abbe => { match => 'lo' },
      bert => { match => 'lo' } },
    { id => '06',  name => 'Nine*Days' },
    { id => '07',  name => 'Water*March' },
    { id => '08',  name => 'River*Waltz',
      Kata => { match => 'melody' }, Abbe => { match => 'melody' },
      bert => { match => 'harmony' } },
    # 09
    { id => '10',  name => 'Pond*Song' },

    #M1  Great White Shark
    #M2  Amazing Water
    #M3  Clouds
    #M4  Water from Drips to Oceans
    #M5  About Liquids
    #M6  Watery Seasons
    #M7  Water and Sand
    { id => 'M8',  name => 'Water*Cycle',
      '*' => { match => '' } },
  );

@ARGV = @auto_groups if ! @ARGV;

for my $arg (@ARGV) {
  if (exists $groups{$arg}) {
    my $dir = "../$arg" if ! $groups{$arg}{no_copy};
    print STDERR "@@@ preparing $dir @@@\n" if $dir;
    for my $track (@tracks) {
      process  $arg, \%groups, $track, {destdir => $dir};
    }
  } else {
    die "Unknown argument '$arg' (known: @groups)\n  encountered";
  }
}
