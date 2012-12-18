#!/bin/sh
wget --load-cookies cookies.txt \
    -A .mp3,.MP3,169 -nd -P mp3-all -N -r -l 1 --restrict-file-names=windows \
    --progress=bar:force \
    http://www.familyopera.org/drupal/node/169 \
  2>&1 | tee download-all.log
rm -f mp3-all/index.html; mv mp3-all/169 mp3-all/index.html
./clean-up.pl download-all.log
