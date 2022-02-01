#!/bin/bash

source "$(dirname "$0")/_uri.sh"

mkdir -p "$video_dir"
(cd "$video_dir" && \
     yt-dlp --windows-filenames \
            --remove-chapters "^(?!Scene 4|At the Spaceport|I'm the Best|It's a Deal|Jabba Jive|The Little Chat|Vader's Orders 2)" \
            --split-chapters \
            https://vimeo.com/ncfo/2019-so-show7-gold \
            https://vimeo.com/ncfo/2019-so-show8-red \
    )
(cd "$video_dir" && \
     yt-dlp --windows-filenames \
            --split-chapters \
            --video-password "$(cat ../.pw.video.cc)" \
            https://vimeo.com/276990605 \
    )
