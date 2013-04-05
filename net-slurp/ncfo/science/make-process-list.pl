#!/usr/bin/perl
use warnings;
use strict;

our $DIR = 'mp3/';
our $EXT = '.mp3';

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
  my $use_wildcards = 1;
 GATHER_FLAGS:
  {
    my %flags;
    for my $f (@flag_sets) {
      %flags = (%flags, %$f);
      # need to do this here, not after the loop, or collisions cause problems:
      %flags = (%flags, %{$f->{'*'}})
	if $use_wildcards and exists $f->{'*'} and ref $f->{'*'};
      %flags = (%flags, %{$f->{$who}})
	if exists $f->{$who} and ref $f->{$who};
    }
    # If we weren't supposed to use wildcards, we have to redo the whole thing.
    exists $flags{no_wildcard_cfg} and $flags{no_wildcard_cfg}
      and $use_wildcards
	and $use_wildcards = 0, redo GATHER_FLAGS;
    !$use_wildcards
      and !(exists $flags{no_wildcard_cfg} and $flags{no_wildcard_cfg})
	and die "Configuration error: should I use wildcards or not?!?";

    #delete $flags{$_} for @groups;
    \%flags;
  }
}

sub matches ( $ ) {
  my ($flags) = @_;
  my $idx = $flags->{id};
  my @name_flags = grep length, @$flags{sort grep /^name/, keys %$flags};
  my @match_flags = grep length, @$flags{sort grep /^match/, keys %$flags};
  my @ignore_flags = grep length, @$flags{sort grep /^ignore/, keys %$flags};

  my $glob = join '*', $DIR, @name_flags, @match_flags, $EXT;
  my @xglobs = map case_expand($_), map curly_expand($_), $glob;
  my @files = map glob($_), @xglobs;

  if (@ignore_flags) {
    if ($flags->{debug}) {
      print STDERR "+++ file matches for $glob +++\n";
      print STDERR "$_\n" for @files;
    }

    my $iglob = join '*', $DIR, @name_flags, @ignore_flags, $EXT;
    my @ixglobs = map case_expand($_), map curly_expand($_), $iglob;
    my @ifiles = map glob($_), @ixglobs;

    if ($flags->{debug}) {
      print STDERR "--- ignore matches for $iglob ---\n";
      print STDERR "$_\n" for @ifiles;
    }

    my %ifiles = map +($_ => 1), @ifiles;
    @files = grep !$ifiles{$_}, @files;
  }

  if ($flags->{debug}) {
    print STDERR "=== file results for $glob ===\n";
    print STDERR "$_\n" for @files;
  }

  @files;
}

sub apply_replacements ( $@ ) {
  my ($text, @replace) = @_;
  for my $rr (@replace) {
    my ($regex, $repl) = @$rr;
    $text =~ s/$regex/$repl/;
  }
  $text;
}

sub find_files ( $@ ) {
  my ($who, @flag_sets) = @_;

  my $flags = flags $who, @flag_sets;
  exists $flags->{skip} and $flags->{skip} and return ($flags, $flags, []);
  my @files = matches $flags;
  return ($flags, $flags, \@files) if @files;

  my @fallback = @{$flags->{fallback}} if exists $flags->{fallback};
  # No cascading failover (we don't try the fallback's fallbacks)
  for my $fbwho (@fallback) {
    my $fbflags = flags $fbwho, @flag_sets;
    # No cascading skip (we don't honor skip during fallback)
    @files = matches $fbflags;
    return ($flags, $fbflags, \@files) if @files;
  }

  # At this point, we've failed; the rest of this is for diagnostics.
  my $showflags = flags 'show', @flag_sets;
  @files = matches $showflags if $who ne 'show';
  my $label = "[$flags->{id}] $flags->{name}";
  if (@files) {
    warn join("\n    ",
	      "*** No files found for $label!  Possibly relevant:",
	      @files) . "\n";
  } else {
    warn "*** No files found for $label, and nothing seems relevant\n";
  }
  ($flags, $showflags, []);
}

sub generate ( $@ ) {
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

  defined $destdir or return @$files;

  for my $i (@$files) {
    my $n = base_filename $i;
    if (exists $flags->{replace}) {
      $n = apply_replacements $n, @{$flags->{replace}};
    }
    my $u = uniform_filename $flags->{id}, '', $n;
    my $d = "$destdir/$u";
    print "$i=$d\n";
  }
  @$files;
}

############################################################

my @group_info =
  ( show => { display => 1, no_copy => 1, show_unmatched => 1,
	      no_wildcard_cfg => 1 },

    Katarina => { match => '{kid,sop}' },
    Abbe => { match => 'alt' },
    bert => { match => '{bass,baritone}' },

    soprano => { match => 'sop' },
    alto => { match => 'alt' },
    tenor => { match => '{tenor,baritone}' },
    Sara => { match => '{alt,tenor}' },

    demo => { match => 'demo', no_wildcard_cfg => 1, fallback => ['piano'] },
    piano => { match => 'piano', no_wildcard_cfg => 1 },
  );
my %groups = @group_info;
my @groups = map $group_info[2*$_], 0..int($#group_info/2);
my @auto_groups = ( qw(Katarina Abbe bert demo) );
my @extra_groups = grep !/^\#/, ( qw(soprano alto tenor Sara) );
my @all_groups = ( @auto_groups, @extra_groups );

my @tracks =
  ( { id => '01',  name => 'Cetac{e,i}an', tenor => { match => 'bass' } },
    { id => '02',  name => 'Living*Light',
      bert => { match => 'bass_hi' } },
    { id => '03',  name => 'Tamar', demo => { match => 'All*Voices' } },
    { id => '04',  name => 'Clouds', ignore => 'Full*Baldwin',
      Katarina => { match => 'kids_hi' }, Abbe => { match => 'alto_lo' } },
    #{ id => '05a', name => 'Sea*Fever*intro' },
    { id => '05c', name => 'Sea*Fever', ignore => '{slow,intro}',
      Katarina => { match => 'hi' }, Abbe => { match => 'lo' },
      bert => { match => 'lo' },
      soprano => { match => 'hi' }, alto => { match => 'lo' },
      tenor => { match => 'hi' }, Sara => { match => '{hi,lo,SaraXXX}' } },
    { id => '05d', name => 'Sea*Fever*slow',
      '*' => { skip => 1 }, 'demo' => { skip => 1 }, 'piano' => { skip => 1 },
      Katarina => { match => 'hi' }, Abbe => { match => 'lo' },
      bert => { match => 'lo' },
      soprano => { match => 'hi' }, alto => { match => 'lo' },
      tenor => { match => 'hi' }, Sara => { match => '{hi,lo,SaraXXX}' } },
    { id => '07',  name => 'Water*March',
      bert => { skip => 'yes_I_have_a_hand_mixed_version' } },
    { id => '08',  name => 'River*Waltz',
      Katarina => { match => 'melody' }, Abbe => { match => 'melody' },
      bert => { match => 'harmony' },
      soprano => { match => 'melody' }, alto => { match => 'melody' },
      tenor => { match => 'harmony' },
      Sara => { match => '{melody,harmony,SaraXXX}' } },
    # 09... number nine... number nine...
    { id => '10',  name => 'Pond*Song',
      '*' => { match => 'practice' }, 'demo' => { match => 'practice' } },
    { id => '11a',  name => 'Big*Ice', ignore => '72',
      replace => [['_86', '']],
      Abbe => { match => 'Hi*Alto' }, tenor => { match => '{tenor,bass}' } },
    { id => '11b',  name => 'Big*Ice*72',
      '*' => { skip => 1 }, 'demo' => { skip => 1 }, 'piano' => { skip => 1 },
      replace => [['72', 'slow']],
      tenor => { match => '{tenor,bass}' } },
    { id => '12',  name => 'Water*Cycle',
      Katarina => { match => 'melody' },
      Abbe => { match => 'Melody' }, bert => { match => 'HiBass' },
      soprano => { match => '{HiHa,Mel}' }, alto => { match => '{Mel,LoHa}' },
      tenor => { match => 'LoHa' }, Sara => { match => '{Mel,LoHa}' },
      piano => { match => '{piano,TVTrack}' } },
    { id => '13',  name => 'Keep*Cool',
      Katarina => { match => 'Hi*Soprano' }, Abbe => { match => 'Lo*Alto' },
      tenor => { match => 'bass' } },
    { id => '14',  name => 'Water*Drops' },
    { id => '15',  name => 'River*Rock',
      tenor => { match => 'bass' } },

    { id => 'M0',  name => 'CPS*Medley', bert => { match => 'tenor' } },

    ## advanced group PLUS KIDS
    { id => 'Z3',  name => 'Clouds*Baldwin',
      Katarina => { match => 'Demo', skip => 0 }, '*' => { skip => 1 },
      'demo' => { skip => 1 }, 'piano' => { skip => 1 } },

    ## advanced group only stuff
    { id => '06',  name => 'Nine*Days', '*' => { skip => 1 },
      'demo' => { skip => 1 }, 'piano' => { skip => 1 } },
    { id => 'Z1',  name => '{Water,Lovely}*Lake', '*' => { skip => 1 },
      'demo' => { skip => 1 }, 'piano' => { skip => 1 } },
    { id => 'Z2',  name => 'Winter*Odyssey', '*' => { skip => 1 },
      'demo' => { skip => 1 }, 'piano' => { skip => 1 } },
    { id => 'Z4',  name => 'Currents*Ocean', '*' => { skip => 1 },
      'demo' => { skip => 1 }, 'piano' => { skip => 1 } },
  );

@ARGV = ('all') if ! @ARGV;

while (@ARGV) {
  my $arg = shift @ARGV;
  if ($arg eq 'all') {
    unshift @ARGV, @all_groups;
  } elsif ($arg eq 'auto') {
    unshift @ARGV, @auto_groups;
  } elsif ($arg eq 'extra') {
    unshift @ARGV, @extra_groups;

  } elsif (exists $groups{$arg}) {
    my $dir = "../$arg" if ! $groups{$arg}{no_copy};
    $dir = "../extra/$arg" if $dir and scalar grep($_ eq $arg, @extra_groups);
    print STDERR "@@@ preparing $dir @@@\n" if $dir;

    my @used_files;
    for my $track (@tracks) {
      push @used_files, generate $arg, \%groups, $track, {destdir => $dir};
    }

    if ($groups{$arg}{show_unmatched}) {
      my @all_files = map glob($_),
	map case_expand($_), map curly_expand($_), "$DIR*$EXT";
      my %used = map +($_ => 1), @used_files;
      my @unused_files = grep ! $used{$_}, @all_files;
      if (@unused_files) {
	print STDERR "--- Unmatched files:\n";
	print STDERR "    $_\n" for @unused_files;
      }
    }

  } else {
    die "Unknown argument '$arg' (known: @groups all)\n  encountered";
  }
}
