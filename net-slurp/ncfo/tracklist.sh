#!/bin/sh

SORT_BY_NUMBER=()
SORT_BY_NAME=()
STRIP_PREFIX=()
while true; do
    case "$1" in
	-s|--sort)
	    # This sorts even playlist data and stdin.
	    SORT_BY_NUMBER=(sort_tracks); shift ;;
	-S|--sort-name)
	    SORT_BY_NAME=(sort); shift ;;
	-p|--no-strip-prefix)
	    STRIP_PREFIX=(cat); shift ;;
	-*)
	    echo "Unknown flag '$1'!" >&2 ; exit 1 ;;
	*)
	    break ;;
    esac
done
if [ -n "${SORT_BY_NUMBER[*]}" -a -n "${SORT_BY_NAME[*]}" ]; then
    echo "Error: --sort (-s) and --sort-name (-S) are mutually exclusive!" >&2
    exit 1
fi
if [ -n "${SORT_BY_NAME[*]}" -a -n "${STRIP_PREFIX[*]}" ]; then
    echo "Error: --sort-name (-S) and --no-strip-prefix (-p) are mutually exclusive!" >&2
    exit 1
fi

## should match the code in playlists.sh
sort_tracks () {
#    sort -t "$sep" -k 2
    perl -lne '$o=$_;s,.*/,,;s,[-_].*,,;print "$_\t$o"' \
	| sort -k 1,1 -k 2 \
	| sed -e 's/.*	//'
}

strip_prefix () {
    perl -pe 's/^[0-9A-Z](\w*[0-9A-Z])?[0-9](\.[0-9])?[a-z]?[-_]//'
}

show_tracks () {
    for arg in "$@"; do
	if [ "$arg" = "-" ]; then
	    cat   # read from stdin
	elif [ -d "$arg" ]; then
	    ls "$arg"/*.[mM][pP]3 | sort_tracks
	elif [ -f "$arg" ]; then
	    case "$arg" in
		*.mp3|*.MP3)
		    echo "$arg" ;;
		*.m3u|*.M3U)
		    sed -e '/^#/d;s/^[ 	]*//;/^$/d' "$arg" ;;
		*)
		    echo "Unknown file argument '$arg'!" >&2; exit 1 ;;
	    esac
	else
	    echo "Unknown argument '$arg'!" >&2; exit 1
	fi
    done
}

show_tracks "$@" \
    | sed -e 's,.*/,,;s/\.mp3$//i' \
    | ${SORT_BY_NUMBER[@]:-cat} \
    | ${STRIP_PREFIX[@]:-strip_prefix} \
    | ${SORT_BY_NAME[@]:-cat} \
    | cat -n
