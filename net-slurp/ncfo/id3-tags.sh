#!/bin/bash

cd ..

PATH="${PATH}:${HOME}/perl-lib/bin"
eyeD3='eyeD3'
verbose=
old_tag_args=(--remove-v1)
new_tag_args=(--to-v2.3)

id3_artist="NCFO practice"
id3_album_prefix="`/bin/pwd | sed -e 's,.*[\\/],,'`: "
id3_album_suffix=" practice"
id3_playlist_strip_style=word2
id3_track_strip_style=none

msg_dir_prefix=

update_tags_from_playlist () {
    local playlist="$1"
    local who="`echo "$playlist" | sed -e 's/\..*//'`"
    case "$id3_playlist_strip_style" in
	none) ;;
	word1) who="`echo "$who" | sed -e 's/ .*//'`" ;;
	word2) who="`echo "$who" | sed -e 's/[^ ]* //;s/ .*//'`" ;;
	word3) who="`echo "$who" | sed -e 's/[^ ]* //;s/[^ ]* //;s/ .*//'`" ;;
	paren) who="`echo "$who" | sed -e 's/[^(]*(//;s/)[^)]*//'`" ;;
	*) echo "Bad strip style '$id3_playlist_strip_style' (ignored)" >&2 ;;
    esac
    case "$who" in
	X-*) who="`echo "$who" | sed -e 's/^X-X*//'`" ;;
    esac
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
	case "$id3_track_strip_style" in
	    none) ;;
	    no_number)
		name="`echo "$name" | sed -e 's/^[0-9][0-9]*[ _-]\?//'`" ;;
	    *) echo "Bad strip style '$id3_track_strip_style' (ignored)" >&2 ;;
	esac
	echo "Updating tags for $file..."
	local cmd=($eyeD3 "${old_tag_args[@]}" "${new_tag_args[@]}" \
                          -t "$name" -a "$id3_artist" \
			  -A "$id3_album_prefix$who$id3_album_suffix" \
			  -n "$track" -N "$num_tracks" -Q "$file" \
			  --preserve-file-times)
	if [ -n "$verbose" ]; then
	    "${cmd[@]}"
	else
	    "${cmd[@]}" >/dev/null 2>&1
	fi
    done < tracks.tmp
    rm -f tracks.tmp
}

default_playlists () {
    ls *.m3u | sort | uniq | sed -e '/^X-/d;/ X-/d'
}

process_playlist () {
    local playlist="$1"
    echo "Updating tags for playlist $msg_dir_prefix$playlist..."
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
	-n) eyeD3='echo "WOULD run: eyeD3"'; shift ;;
	-v) verbose=yes; shift ;;
	-a) id3_artist="$2"; shift; shift ;;
	-p) id3_album_prefix="$2"; shift; shift ;;
	-s) id3_album_suffix="$2"; shift; shift ;;
	-xx) id3_playlist_strip_style=none; shift ;;
	-xw1) id3_playlist_strip_style=word1; shift ;;
	-xw2) id3_playlist_strip_style=word2; shift ;;
	-xw3) id3_playlist_strip_style=word3; shift ;;
	-xp) id3_playlist_strip_style=paren; shift ;;
	-tx) id3_track_strip_style=none; shift ;;
	-tn) id3_track_strip_style=no_number; shift ;;
	-W|--wipe) old_tag_args=(--remove-all); shift ;;
	-k|--keep) old_tag_args=(); new_tag_args=(); shift ;;
	-3|-2.3) new_tag_args=(--to-v2.3); shift ;;
	-4|-2.4) new_tag_args=(--to-v2.4); shift ;;
	-d) if ! cd "$2"; then echo "$0: couldn't cd to '$2'!" >&2; exit 1; fi
	    msg_dir_prefix="$msg_dir_prefix$2/"; shift; shift ;;
	*)  break ;;
    esac
done

if [ "$#" -eq 0 ]; then
    rm -f id3-tags.*.log
    default_playlists | process_playlist_lines
else
    process_playlist_args "$@"
fi
