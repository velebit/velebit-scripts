#!/bin/sh

cd ..

PATH="${PATH}:${HOME}/perl-lib/bin"
mp3info2='mp3info2'
verbose=

update_tags_from_playlist () {
    local playlist="$1"
    local who="`echo "$playlist" | sed -e 's/\..*//;s/ .*//'`"
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
	if [ -n "$verbose" ]; then
	    $mp3info2 -D "$file"
	fi
    done < tracks.tmp
    rm -f tracks.tmp
}

default_playlists () {
    ls *.m3u | sort | uniq | sed -e '/^X-/d'
}

process_playlist () {
    local playlist="$1"
    echo "Updating tags for playlist $playlist..."
    LOG=id3-tags."$playlist".log
    update_tags_from_playlist "$playlist" > "$LOG" 2>&1
    sed -e '/^Updating tags for /d;/^Need to change /d' "$LOG"
}

process_playlist_args () {
    local playlist
    for playlist in "$@"; do
	process_playlist "$playlist"
    done
}
process_playlist_lines () {
    local playlist
    while IFS='' read -r playlist; do
	process_playlist "$playlist"
    done
}

while true; do
    case "$1" in
	-n) mp3info2='mp3info2 -D'; shift ;;
	-v) verbose=yes; shift ;;
	*)  break ;;
    esac
done

if [ "$#" -eq 0 ]; then
    rm -f id3-tags.*.log
    default_playlists | process_playlist_lines
else
    process_playlist_args "$@"
fi
