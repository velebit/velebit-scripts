#!/bin/sh
wget --load-cookies cookies.txt \
    -A .mp3,.MP3,169 -nd -P mp3 -N -r -l 1 --restrict-file-names=windows \
    --progress=bar:force \
    http://www.familyopera.org/drupal/node/169 \
  2>&1 | tee download.log
rm -f mp3/index.html; mv mp3/169 mp3/index.html
./clean-up.pl download.log
