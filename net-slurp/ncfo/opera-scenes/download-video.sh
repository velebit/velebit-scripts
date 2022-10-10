#!/bin/bash

source "$(dirname "$0")/_uri.sh"
download_perf=
download_ncfo=yes

## EXTERNAL DOWNLOADS -- PERFORMANCES

if [ -n "$download_perf" ]; then
    mkdir -p "$video_perf_dir"
    (cd "$video_perf_dir" && \
         yt-dlp --windows-filenames \
                --remove-chapters "^(?!Scene 4|At the Spaceport|I'm the Best|It's a Deal|Jabba Jive|The Little Chat|Vader's Orders 2)" \
                --split-chapters \
                https://vimeo.com/ncfo/2019-so-show7-gold \
                https://vimeo.com/ncfo/2019-so-show8-red \
        )
    (cd "$video_perf_dir" && \
         yt-dlp --windows-filenames \
                --split-chapters \
                --video-password "$(cat ../.pw.video.cc)" \
                https://vimeo.com/276990605 \
        )
fi

## OPERA WEBSITE DOWNLOADS

if [ -n "$download_ncfo" ]; then
    file="`basename "$video_uri"`"
    type=video
    file_dir="$video_dir"
    html_dir=html
    html_ext=.html
    log=download-"$type".log
    if [ -f "$html_dir/$file$html_ext" ]; then
        rm -f "$file_dir/$file"; mv "$html_dir/$file$html_ext" "$file_dir/$file"; fi
    cp -p "$file_dir/$file" "$file_dir/$file".orig
    wget --load-cookies cookies.txt \
         -nd -P "$file_dir" -N --restrict-file-names=windows \
         -r -l 1 -A .mp4,.MP4,"$file",index.html \
         --reject-regex '^http://www.familyopera.org/drupal/$' \
         --progress=bar:force \
         "$video_uri" \
         2>&1 | tee "$log"
    if [ -f "$file_dir/$file" ]; then
        rm -f "$html_dir/$file$html_ext" "$file_dir/$file".orig
        mv "$file_dir/$file" "$html_dir/$file$html_ext"
        ./clean-up.pl -i "$file" -i index.html "$log"
    elif [ -f "$file_dir/$file".orig ]; then
        rm -f "$html_dir/$file$html_ext" "$file_dir/$file"
        mv "$file_dir/$file".orig "$html_dir/$file$html_ext"
        echo "(index not downloaded)"
    else
        echo "(index not downloaded, original missing)"
    fi
fi
