#!/bin/sh
find . -name '*.mp3' -o -name '*.aac' -o -name '*.m4a' \
    -o -name '*.m3u' -o -name '*.wpl' -o -name '*.jpg' \
    -o -name '*~' -o -type f -print
