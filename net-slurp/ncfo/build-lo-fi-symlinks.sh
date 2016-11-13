#!/bin/sh
mp3_links_dir='../for-lo-fi/NCFO practice'
video_out_dir='../video/lo-fi/'

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
	echo "$mp3_links_dir/$dst -> $src"
	ln -s ../../"$src" "$mp3_links_dir"/"$dst"
    fi
done
cp convert-mp3-lo-fi.sh "`dirname "$mp3_links_dir"`"

if [ -e convert-video-lo-fi.sh ]; then
    mkdir -p "$video_out_dir"
    cp /home/bert/scripts/music/reduce-bitrate.sh "$video_out_dir"
    cp convert-video-lo-fi.sh "`dirname "$video_out_dir"`"
fi
