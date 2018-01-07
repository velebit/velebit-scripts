#!/bin/sh
cd "`dirname "$0"`" || exit 1
lo_fi_dir='./lo-fi'
echo "Working in $lo_fi_dir ..."
"$lo_fi_dir"/reduce-bitrate.sh -P6 -v --video with-subdirs/*
