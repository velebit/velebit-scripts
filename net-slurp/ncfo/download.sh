#!/bin/sh
wget --load-cookies cookies.txt \
    -A .mp3,.MP3 -nd -P mp3 -N -r -l 1 --restrict-file-names=windows \
    --progress=bar:force \
    http://www.familyopera.org/drupal/node/115 \
  2>&1 | tee download.log
./clean-up.pl download.log
