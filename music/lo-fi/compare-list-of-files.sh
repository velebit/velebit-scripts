#!/bin/bash
# Compare the lists of all tracks from the current directory and from lo-fi.

canonical_file_list () {
    find . -name '00_playlist*' -o -name '*.jpg' -o -name '*.png' \
         -o -name '*.pdf' -o -name '*.sh' -o -name '*.pl' -o -name '*.py' \
         -o -print | sed -e 's,\.\(m4a\|flac\|mp3\)$,.<audio>,' | sort
}

canonical_file_list > /tmp/fl_ours.txt
(cd "$(dirname "$0")"; canonical_file_list > /tmp/fl_lofi.txt)
meld /tmp/fl_ours.txt /tmp/fl_lofi.txt
rm -f /tmp/fl_ours.txt /tmp/fl_lofi.txt
