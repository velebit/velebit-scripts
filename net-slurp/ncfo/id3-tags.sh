#!/bin/bash

PATH="${PATH}:${HOME}/perl-lib/bin"
eyeD3='eyeD3'
verbose=
old_tag_args=(--remove-v1)
new_tag_args=(--to-v2.3)

id3_artist="NCFO practice"
id3_album_prefix="`cd ..; /bin/pwd | sed -e 's,.*[\\/],,'`: "
id3_album_suffix=" practice"
id3_playlist_strip_style=word2
id3_track_strip_style=none

this_script="$0"
case "$this_script" in
    /*) ;;
    *)  this_script="`/bin/pwd`/$this_script" ;;
esac

dir_prefix=

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
    local tracks="`tempfile -p tracks_ -s .tmp`"
    sed -e '/^ *<media src="/{;s|^[^"]*"||;s|".*||;s|&amp;|&|g;}' \
	-e '/^#/d' -e '/^</d' -e '/^[ 	]/d' -e '/^$/d' \
	"$playlist" > "$tracks"
    local num_tracks=$((`wc -l < "$tracks"` + 0))
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
    done < "$tracks"
    rm -f "$tracks"
}

default_playlists () {
    ls *.m3u | sort | uniq | sed -e '/^X-/d;/ X-/d'
}

process_playlist () {
    local playlist="$1"
    echo "Updating tags for playlist $dir_prefix$playlist..."
    LOG=id3-tags."$playlist".log
    update_tags_from_playlist "$playlist" > "$LOG" 2>&1
    sed -e '/^Updating tags for /d;/^Need to change /d' "$LOG"
}

cargs=()

process_playlist_lines () {
    xargs -r -d '\n' -P "`nproc`" -n 1 -I '{}' \
	  "$this_script" "${cargs[@]}" --process-playlist '{}'
}
process_playlist_args () {
    local playlist
    for playlist in "$@"; do echo "$playlist"; done \
	| process_playlist_lines
}

while true; do
    case "$1" in
	-n) eyeD3='echo "WOULD run: eyeD3"'; cargs+=("$1"); shift ;;
	-v) verbose=yes; cargs+=("$1"); shift ;;
	-a) id3_artist="$2"; cargs+=("$1" "$2"); shift; shift ;;
	-p) id3_album_prefix="$2"; cargs+=("$1" "$2"); shift; shift ;;
	-s) id3_album_suffix="$2"; cargs+=("$1" "$2"); shift; shift ;;
	-xx) id3_playlist_strip_style=none; cargs+=("$1"); shift ;;
	-xw1) id3_playlist_strip_style=word1; cargs+=("$1"); shift ;;
	-xw2) id3_playlist_strip_style=word2; cargs+=("$1"); shift ;;
	-xw3) id3_playlist_strip_style=word3; cargs+=("$1"); shift ;;
	-xp) id3_playlist_strip_style=paren; cargs+=("$1"); shift ;;
	-tx) id3_track_strip_style=none; cargs+=("$1"); shift ;;
	-tn) id3_track_strip_style=no_number; cargs+=("$1"); shift ;;
	-W|--wipe) old_tag_args=(--remove-all); cargs+=("$1"); shift ;;
	-k|--keep) old_tag_args=(); new_tag_args=(); cargs+=("$1"); shift ;;
	-3|-2.3) new_tag_args=(--to-v2.3); cargs+=("$1"); shift ;;
	-4|-2.4) new_tag_args=(--to-v2.4); cargs+=("$1"); shift ;;
	-d) dir_prefix="$dir_prefix$2/"; cargs+=("$1" "$2"); shift; shift ;;
	--process-playlist) process_playlist "$2"; exit 0 ;;
	*)  break ;;
    esac
done

cd "../$dir_prefix" || exit 1

if [ "$#" -eq 0 ]; then
    rm -f id3-tags.*.log
    default_playlists | process_playlist_lines
else
    process_playlist_args "$@"
fi
