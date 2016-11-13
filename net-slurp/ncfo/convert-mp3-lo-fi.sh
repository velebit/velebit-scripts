#!/bin/sh
cd "`dirname "$0"`" || exit 1
lo_fi_dir='../../../lo-fi'
seen=
for top_dir in 'NCFO practice' 'North Cambridge Family Opera' \
    'NCFO Science Festival Chorus'; do
  if [ -d "$top_dir" ]; then
      seen=yes
      echo "Working: $top_dir -> $lo_fi_dir ..."
      "$lo_fi_dir"/reduce-bitrate.sh -P6 -v "$top_dir"/*
  fi
done
if [ -z "$seen" ]; then
    echo "No source directories found"
fi
