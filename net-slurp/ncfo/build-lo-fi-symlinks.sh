#!/bin/bash

mp3_links_dir='../for-lo-fi/NCFO practice'
video_out_dir='../video/lo-fi'

case "`/bin/pwd`" in
    */performance/*)
	case "`readlink download-mp3.sh`" in
	    *-o20[01][0-9]-*)
		mp3_links_dir='../for-lo-fi/North Cambridge Family Opera' ;;
	    *-s20[01][0-9]-*)
		mp3_links_dir='../for-lo-fi/NCFO Science Festival Chorus' ;;
	    "")
		echo "download-mp3.sh isn't a symlink!  can't guess" >&2
		exit 1 ;;
	    *)
		echo "download-mp3.sh link not recognizable!  can't guess" >&2
		exit 1 ;;
	esac
	;;
esac

######################################################################

symlink () {
    local target_path="$1"; shift
    local symlink_path="$1"; shift
    #echo "$symlink_path -> $target_path"
    echo "$symlink_path -> $(basename "$target_path")"
    rm -f "$symlink_path"
    ln -s "$target_path" "$symlink_path"
}

rpath () {
    local path="$1"; shift
    local rprefix="$1"; shift
    case "$rprefix" in
	.|./)   rprefix= ;;
	*/)     ;;
	*)      rprefix="$rprefix/" ;;
    esac
    case "$path" in
	/*) echo "$path" ;;
	*)  echo "$rprefix$path" ;;
    esac
}

rlpath () {
    local path="$1"; shift
    local prefix="$1"; shift
    local rprefix="${1-$prefix}"; shift

    local lpath="$(readlink "$(rpath "$path" "$rprefix")")"
    while [ -n "$lpath" ]; do
	path="$(rpath "$lpath" "$(dirname "$path")")"
	lpath="$(readlink "$(rpath "$path" "$rprefix")")"
    done
    rpath "$path" "$prefix"
}

back_path () {
    local path="$1"; shift
    local wd="${1-.}"; shift
    case "$path" in
	/*) echo "$path"; return ;;
    esac

    wd="$(realpath "$wd")"
    if [ -z "$wd" ]; then exit 9; fi
    local back="."
    while [ "x$path" != "x." ]; do
	case "$path" in
	    ./*)    path="${path#./}" ;;
	    ../*)   back="$(basename "$wd")/$back"; wd="$(dirname "$wd")"
		    path="${path#../}" ;;
	    */?*)   back="../$back"; wd="$(realpath "$wd/${path%%/*}")"
		    path="${path#*/}" ;;
	    *)      back="../$back"; wd="$(realpath "$wd/$path")"
		    path="." ;;
	esac
    done
    echo "${back%/.}"
}

back_link () {
    local path="$1"; shift
    local wd="${1-.}"; shift

    local dir="$(dirname "$path")"
    local back="$(back_path "$dir" "$wd")/$(basename "$path")"
    #symlink "$(rlpath "$back" "" "$dir")" "$path"
    symlink "$back" "$path"
}

######################################################################

rm -rf "$mp3_links_dir"
mkdir -p "$mp3_links_dir"
for i in ../*.m3u; do
    base="`basename "$i" .m3u`"
    #src="`echo "$base" | sed -e 's/ practice$//;s/.* //'`"
    src="`sed -e '/^#/d;/^$/d;\,/,!s,^,./,;s,/[^/]*$,,;s,.*/,,' "$i"|head -1`"
    dst="`echo "$base" | sed -e 's/\( orchestra\) practice$/\1/'`"
    case "$src" in
	X-*)
	    #echo "** $src: skipped." >&2
	    continue ;;
    esac
    if [ ! -d ../"$src" ]; then
	echo "** $src: missing." >&2
	continue
    elif [ -L "$mp3_links_dir"/"$dst" ]; then
	echo "** $src: duplicate." >&2
	continue
    else
	symlink ../../"$src" "$mp3_links_dir"/"$dst"
    fi
done
back_link "$(dirname "$mp3_links_dir")"/convert-mp3-lo-fi.sh

if [ -e convert-video-lo-fi.sh ]; then
    mkdir -p "$video_out_dir"
    back_link "$video_out_dir"/reduce-bitrate.sh
    back_link "$(dirname "$video_out_dir")"/convert-video-lo-fi.sh
fi
