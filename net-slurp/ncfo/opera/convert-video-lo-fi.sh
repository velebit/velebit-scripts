#!/bin/sh

PARALLEL=-P6
VERBOSE='-v -Ve'   #'-v -Vi'
ERASE_OLD=

cd "`dirname "$0"`" || exit 1
lo_fi_dir='./lo-fi'
seen=
for top_dir in 'with-subdirs'; do
  if [ -d "$top_dir" ]; then
    seen=yes
    if [ -n "$ERASE_OLD" ]; then
      for second_dir in "$top_dir"/*; do
	old_dir="$lo_fi_dir/$top_dir/`basename "$second_dir"`"
	if [ -d "$old_dir" ]; then
	  echo "Removing old $old_dir";
	  rm -rf "$old_dir"
	fi
      done
    fi
    echo "Working: $top_dir -> $lo_fi_dir ..."
    "$lo_fi_dir"/reduce-bitrate.sh $PARALLEL $VERBOSE --video "$top_dir"/*/
  fi
done
if [ -z "$seen" ]; then
  echo "No source directories found"
fi
