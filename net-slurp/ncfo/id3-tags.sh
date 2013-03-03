#!/bin/sh

cd ..

PATH="${PATH}:${HOME}/perl-lib/bin"
mp3info2='mp3info2'

update_tags_from_playlist () {
    local playlist="$1"
    local who="`echo "$playlist" | sed -e 's/\..*//'`"
    local title="`/bin/pwd | sed -e 's,.*[\\/],,'`"
    ##local year="`date +'%Y'`"
    # This extracts just the file names from either a M3U or WPL playlist.
    sed -e '/^ *<media src="/{;s|^[^"]*"||;s|".*||;s|&amp;|&|g;}' \
	-e '/^#/d' -e '/^</d' -e '/^[ 	]/d' -e '/^$/d' \
	"$playlist" > tracks.tmp
    local num_tracks=$((`wc -l < tracks.tmp` + 0))
    local track=0
    while IFS='' read -r file; do
	track=$(($track + 1))
	local name="`echo "$file" | sed -e 's,.*/,,' -e 's/\.mp3$//i'`"
	echo "Updating tags for $file..."
	##$mp3info2 -d ID3v1,ID3v2 -p "" "$file"
	$mp3info2 -t "$name" -a "NCFO practice" -l "$title: $who practice" \
	    -n "$track/$num_tracks" -p "" "$file"
    done < tracks.tmp
    rm -f tracks.tmp
}

default_playlists () {
    ls *.m3u | sort | uniq
}

if [ "$1" = "-n" ]; then mp3info2='mp3info2 -D'; shift; fi

if [ "$#" -eq 0 ]; then set -- `default_playlists`; fi
for playlist in "$@"; do
    update_tags_from_playlist "$playlist"
done
