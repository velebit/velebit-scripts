#!/bin/sh
NODE=197
wget --load-cookies cookies.txt \
    -A .mp3,.MP3,"$NODE" -nd -P mp3-all -N -r -l 1 \
    --restrict-file-names=windows \
    --progress=bar:force \
    http://www.familyopera.org/drupal/node/"$NODE" \
  2>&1 | tee download-all.log
rm -f mp3-all/index.html; mv mp3-all/"$NODE" mp3-all/index.html
./clean-up.pl download-all.log
