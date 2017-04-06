#!/bin/sh

if [ "$#" -eq 0 ]; then
    echo "Usage: `basename "$0"` PLAYLIST.m3u..." >&2
    exit 1
fi

mkdir_p() {
    if [ "$2" != "." ]; then
	mkdir_p "$1" "`dirname "$2"`"
	if [ ! -d "$1/$2" ]; then
	    mkdir "$1/$2" >/dev/null 2>&1
	fi
    fi
}

PATH="$PATH":"/c/tools/ffmpeg/ffmpeg-2.8.5-win64-static/bin"
#PATH="$PATH":"/c/tools/ffmpeg/ffmpeg-20150113-git-b23a866-win64-static/bin"
PATH="$PATH":"$HOME/My Apps/FFmpeg/bin"
ffmpeg=ffmpeg
if ffmpeg -version >/dev/null 2>&1; then
    ffmpeg=ffmpeg
elif avconv -version >/dev/null 2>&1; then
    ffmpeg=avconv
else
    echo "Warning: ffmpeg/avconv not found!" >&2
fi

convert_audio () {
    src="$1"; shift
    dst="$1"; shift
    $ffmpeg -v verbose -y -i "$src" -vn -ar 44100 "$dst" < /dev/null
}

convert_m3u () {
    src_dir="$1"; shift
    comment_suffix=" (converted to wav for CD)"
    while read line; do
	case "$line" in
	    '#'*)
		echo "$line$comment_suffix"
		;;
	    /*.mp3|/*.wav)
		in_dir="`dirname "$line"`"
		out_dir="cd_`basename "$in_dir"`"
		base="`basename "$line"`"
		mkdir_p "$out_dir"
		convert_audio "$line" "$out_dir/$base.wav" || exit 1
		echo "$out_dir/$base.wav"
		;;
	    *.mp3|*.wav)
		in_dir="`dirname "$src_dir/$line"`"
		out_dir="cd_`basename "$in_dir"`"
		base="`basename "$line"`"
		mkdir_p "$out_dir"
		convert_audio "$src_dir/$line" "$out_dir/$base.wav" || exit 1
		echo "$out_dir/$base.wav"
		;;
	    *)
		echo "  skipping: $line" >&2
		;;
	esac
	comment_suffix=""
    done
}

for in_list in "$@"; do
    case "$in_list" in
	-)
	    echo "Working: stdin -> stdout" >&2
	    convert_m3u
	    ;;
	*.m3u)
	    out_list="cd_`basename "$in_list"`"
	    in_dir="`dirname "$in_list"`"
	    echo "Working: $in_list -> $out_list" >&2
	    if ! convert_m3u "$in_dir" < "$in_list" > "$out_list".tmp; then
		rm -f "$out_list".tmp
		echo "  failed" >&2
	    fi
	    if grep -qv '^#' "$out_list".tmp; then
		mv "$out_list".tmp "$out_list"
		echo "  done" >&2
	    else
		rm -f "$out_list".tmp
		echo "  no files converted" >&2
	    fi
	    rm -f "$out_list".tmp
	    ;;
	*)
	    echo "Skipped: $in_list" >&2
	    ;;
    esac
done
