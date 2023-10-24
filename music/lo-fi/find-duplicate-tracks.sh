#!/bin/bash
# Find directories where more than one track has the same number.

# duplicates are expected in NCFO practice and LLM all-locations performance

find . -name 'NCFO practice' -prune \
     -o -name 'Little Light Music 2015 (all)' \
     -o -type d -print0 \
    | while read -d '' dir; do
          perl -le 'for my $dir (@ARGV) {
                      opendir my $DH, $dir or die "$!";
                      while (readdir $DH) {
                        /^\.\.?$/&&next;
                        /^00_/&&next;  # playlists in mp3 dir
                        -d "$dir/$_" and next;
                        s/^((?:\d{1,2}-|LLM-|LLM|KC|SotR|ISW|OWS|WoL|GoS|Dar Williams - Dar Williams Folkadelphia Session 6-26-2015 - |Antiphony2002_cast._|RainDance._)?\d\d[a-z]?[- _\.]|Haman2010_Show\d_\d\d).*/$1/||next;
                        print "$dir/$_"
                      }
                    }' "$dir"
          done \
    | sort | uniq -c | sed -e '/^[      ]*1 /d'
