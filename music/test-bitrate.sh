#!/bin/sh

PATH="$PATH":'/c/tools/ffmpeg/ffmpeg-20150113-git-b23a866-win64-static/bin'

for i in "$@"; do
    b="`basename "$i" '.mp3'`"
    for r in 64k 96k 128k; do
	ffmpeg -i "$i" -vn -b:a "$r" "$b"."$r".aac
	ffmpeg -i "$i" -vn -b:a "$r" "$b"."$r".mp3
    done
done
