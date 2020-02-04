#!/bin/bash

CUE_SHEET=
SORT_BY_NUMBER=()
SORT_BY_NAME=()
STRIP_PREFIX=()
REPLACE_SPACES=()
NUMBERING=()
while true; do
    case "$1" in
	-s|--sort)
	    # This sorts even playlist data and stdin.
	    SORT_BY_NUMBER=(sort_tracks); shift ;;
	-S|--sort-name)
	    SORT_BY_NAME=(sort); shift ;;
	-p|--no-strip-prefix)
	    STRIP_PREFIX=(cat); shift ;;
	-w|--keep-word-separators)
	    REPLACE_SPACES=(cat); shift ;;
	-d|--decimate)
	    NUMBERING=(decimate_and_number "$2"); shift; shift ;;
	--cue|--cue-sheet)
	    CUE_SHEET=yes; shift ;;
	-?*)
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
if [ -n "$CUE_SHEET" -a -n "${NUMBERING[*]}" ]; then
    echo "Error: --cue and --decimate (-d) are mutually exclusive!" >&2
    exit 1
fi

sort_tracks () {
#    sort -t "$sep" -k 2
    perl -lne '$o=$_;s,.*/,,;s,[-_].*,,;print "$_\t$o"' \
	| sort -k 1,1 -k 2 \
	| sed -e 's/.*	//'
}

strip_prefix () {
    perl -pe 's/^[0-9A-Z](\w*[0-9A-Z])?(?:[0-9](\.[0-9])?[a-z]?|\+[a-z])[-_\s]//'
}

strip_part () {
    perl -pe 's/^[SATB](?:mix)? //'
}

canonicalize_name () {
    #perl -pe 's/^pan /panned: /;s, w , w/ ,;s/\bsc(\d\S*)/Scene \1:/'
    perl -pe 's/^pan //;s/,? w /, panned: /;s/^sc(\d\S*)/Scene \1:/'
}

decimate_and_number () {
    local decimate="$1"; shift
    local num=0
    local last=0
    local line
    while IFS='' read -r line; do
	num=$(("$num"+1))
	if [ "($decimate)" = "(1)" ]; then
	    last="$num"
	    printf '%2d %s\n' "$num" "$line"
	elif [ "$(((num-1) % decimate))" -eq 0 ]; then
	    last=$((num+decimate-1))
	    printf '%2d-%-2d %s\n' "$num" "$last" "$line"
	fi
    done
    if [ "$num" -ne "$last" ]; then
	echo "Warning: expected $last tracks, found $num." >&2
    fi
}

show_tracks () {
    for arg in "$@"; do
	if [ "$arg" = "-" ]; then
	    sed -e '/^#/d;s/^[ 	]*//;/^$/d'   # read from stdin
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

cue_header () {
    echo "PERFORMER \"NCFO practice\""
    echo "TITLE \"$(./canonicalize-filenames.pl -ps) practice\""
}
cue_track () {
    local file="$1"; shift
    local type="$1"; shift
    local name="$1"; shift
    local track="$1"; shift
    printf "FILE \"%s\" %s\n" "$file" "$type"
    printf "  TRACK %02d %s\n" "$track" AUDIO
    printf "    TITLE \"%s\"\n" "$name"
    echo   "    PERFORMER \"NCFO practice\""
    echo   "    INDEX 01 00:00:00"
}

declare -A cue_pos

make_cue_sheet () {
    local file
    while IFS='' read -r file; do
	local dir="$(dirname "$file")"
	local pretty="$(echo "$file" | process_tracks)"
	if [ -z "${cue_pos[$dir]}" ]; then
	    cue_pos[$dir]=0
	    cue_header > "$dir"/tracks.cue
	fi
	cue_pos[$dir]=$(("${cue_pos[$dir]}"+1))
	cue_track "$(basename "$file")" MP3 "$pretty" "${cue_pos[$dir]}" \
		  >> "$dir"/tracks.cue
    done
}

process_tracks () {
    sed -e 's,.*/,,;s/\.wav$//i;s/\.mp3$//i' \
	| ${SORT_BY_NUMBER[@]:-cat} \
	| ${STRIP_PREFIX[@]:-strip_prefix} \
	| strip_part \
	| canonicalize_name \
	| ${SORT_BY_NAME[@]:-cat} \
	| ${REPLACE_SPACES[@]:-sed -e 's/[-_][-_]*/ /g'}
}

if [ -n "$CUE_SHEET" ]; then
    show_tracks "$@" \
	| make_cue_sheet
else
    show_tracks "$@" \
	| process_tracks \
	| ${NUMBERING[@]:-cat -n}
fi
