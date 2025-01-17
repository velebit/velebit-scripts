#!/bin/bash

abs_path() {
    case "$1" in
	/*|[a-zA-Z]:[\\/]*)
	    echo "$1" ;;
	*)
	    echo "`pwd`/$1" ;;
    esac
}
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
id3copy="$HOME/scripts/music/id3copy -f"

verbose=
log_level='-v info -nostats'
run=
out_dir="`dirname "$0"`"
out_dir="`abs_path "$out_dir"`"
mode=audio
audio_rate=96k
video_rate=96k
audio_ext=.mp3
video_ext=.mp4
xargs_parallel=()
child_flags=
update_all=
update_older=
find_args=()

while [ "$#" -gt 0 ]; do
    arg="$1"; shift
    case "$arg" in
	-P)  xargs_parallel=( -P "$1" -l3 ); shift ;;
	-P*) xargs_parallel=( -P "`echo "$arg" | sed -e 's/^..//'`" -l3 ) ;;
	-r)  audio_rate="$1"; shift;
             child_flags="$child_flags -r '$audio_rate'" ;;
	-r*) audio_rate="`echo "$arg" | sed -e 's/^..//'`";
             child_flags="$child_flags -r '$audio_rate'" ;;
	-R)  video_rate="$1"; shift;
             child_flags="$child_flags -R '$video_rate'" ;;
	-R*) video_rate="`echo "$arg" | sed -e 's/^..//'`";
             child_flags="$child_flags -R '$video_rate'" ;;
	-n)  run='echo $'; child_flags="$child_flags -n" ;;
	-v)  verbose=yes; child_flags="$child_flags -v" ;;
	-Vv) log_level='-v verbose -stats'; child_flags="$child_flags -Vv" ;;
	-Vi) log_level='-v info -nostats'; child_flags="$child_flags -Vi" ;;
	-Ve) log_level='-v error -nostats'; child_flags="$child_flags -Ve" ;;
	--audio)  mode=audio; child_flags="$child_flags --audio" ;;
	--video)  mode=video; child_flags="$child_flags --video" ;;
	-f|--force) update_all=yes; child_flags="$child_flags $arg" ;;
	-o|--older) update_older=yes; child_flags="$child_flags $arg" ;;
	--follow) find_args+=( -L ) ;;
	-*)  echo "Unknown flag '$arg'!" >&2; exit 1 ;;
	/*|[a-zA-Z]:[\\/]*)
	    echo "Absolute path '$arg' will be ignored!" >&2 ;;
	*/../*|*/..|../*)
	    echo "Path with parent references '$arg' will be ignored!" >&2 ;;
	*.[mM][pP]3|*.[mM]4[aA]|*.[aA][aA][cC]|*.[fF][lL][aA][cC])
	    if [ -d "$arg" ]; then
		echo ": $arg [skipped: strange directory]" >&2
	    elif [ "$mode" = video ]; then
		echo ": $arg [skipped: only processing video]" >&2
	    else
		new_dir="./$arg"
		new_dir="${new_dir%/*}"
		new_dir="${new_dir#./}"
		new_file="${arg##*/}"
		new_file="${new_file%.[mM][pP]3}"
		new_file="${new_file%.[mM]4[aA]}"
		new_file="${new_file%.[aA][aA][cC]}"
		new_file="${new_file%.[fF][lL][aA][cC]}"
		new_file="$new_file$audio_ext"
		if [ ! -d "$out_dir/$new_dir" ]; then
		    $run mkdir_p "$out_dir" "$new_dir"
		fi
		if [ ! -d "$out_dir/$new_dir" -a -z "$run" ]; then continue; fi

		run_conversion=
		if [ ! -f "$out_dir/$new_dir/$new_file" ]; then
		    run_conversion=yes
		elif [ -n "$update_all" ]; then
		    run_conversion=yes
		elif [ -n "$update_older" ]; then
		    if [ "$out_dir/$new_dir/$new_file" -nt "$arg" ]; then
			if [ -n "$run" -o -n "$verbose" ]; then
			    echo ". $arg [skipped: is already newer]" >&2
			fi
		    else
			run_conversion=yes
		    fi
		else
		    if [ -n "$run" -o -n "$verbose" ]; then
			echo ". $arg [skipped: already exists]" >&2
		    fi
		fi
		if [ -n "$run_conversion" ]; then
		    echo "> $new_dir/$new_file" >&2
		    $run $ffmpeg $log_level -y \
			-i "$arg" -vn -b:a "$audio_rate" \
			"$out_dir/$new_dir/$new_file" \
			< /dev/null
                    case "$arg" in
                        *.[mM][pP]3)
		            if ! $run $id3copy "$arg" \
                                 "$out_dir/$new_dir/$new_file"; then
                                echo "@ Could not copy ID3 information!" >&2
                            fi
                            ;;
                        *)
		            if [ -n "$run" ]; then
                                echo "@ Would only update ID3 version." >&2
                            elif [ -n "$verbose" ]; then
                                echo "@ Could not copy full ID3 data from" \
                                     "non-MP3 file! Only updating ID3" \
                                     "version." >&2
                            fi
		            if ! $run eyeD3 --to-v2.3 \
                                 "$out_dir/$new_dir/$new_file"; then
                                echo "@ Could not update ID3 version!" >&2
                            fi
                            ;;
                    esac
		fi
	    fi
	    ;;
	*.[mM][pP]4|*.[mM][oO][vV])
	    if [ -d "$arg" ]; then
		echo ": $arg [skipped: strange directory]" >&2
	    elif [ "$mode" = audio ]; then
		echo ": $arg [skipped: only processing audio]" >&2
	    else
		new_dir="./$arg"
		new_dir="${new_dir%/*}"
		new_dir="${new_dir#./}"
		new_file="${arg##*/}"
		new_file="${new_file%.[mM][pP]4}"
		new_file="${new_file%.[mM][oO][vV]}"
		new_file="$new_file$video_ext"
		if [ ! -d "$out_dir/$new_dir" ]; then
		    $run mkdir_p "$out_dir" "$new_dir"
		fi
		if [ ! -d "$out_dir/$new_dir" -a -z "$run" ]; then continue; fi
		if [ -f "$out_dir/$new_dir/$new_file" ]; then
		    if [ -n "$run" -o -n "$verbose" ]; then
			echo ". $arg [skipped: already exists]" >&2
		    fi
		else
		    echo "> $new_dir/$new_file" >&2
		    $run $ffmpeg $log_level -y -strict experimental \
			-i "$arg" -b:a "$audio_rate" \
			"$out_dir/$new_dir/$new_file" \
			< /dev/null
                    # video file; no need to copy ID3 info
		fi
	    fi
	    ;;
	*)
	    if [ -d "$arg" ]; then
		echo "D $arg [directory]" >&2
		case "$mode" in
		    audio)  files="-name *.[mM][pP]3"
			    files="$files -o -name *.[mM]4[aA]"
			    files="$files -o -name *.[aA][aA][cC]"
			    files="$files -o -name *.[fF][lL][aA][cC]" ;;
		    video)  files="-name *.[mM][pP]4"
			    files="$files -o -name *.[mM][oO][vV]" ;;
		esac
		find "${find_args[@]}" "$arg" \( $files \) -type f -print0 \
		    | xargs --no-run-if-empty -0 "${xargs_parallel[@]}" \
		        "$0" $child_flags
	    else
		echo ". $arg [skipped: unknown file type]" >&2
	    fi
	    ;;
    esac
done
