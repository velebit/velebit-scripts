#!/bin/sh
NODE=197
wget --load-cookies cookies.txt \
    -A .mp4,.MP4,"$NODE" -nd -P video-all -N -r -l 1 \
    --restrict-file-names=windows \
    --progress=bar:force \
    http://www.familyopera.org/drupal/node/"$NODE" \
  2>&1 | tee download-all-video.log
rm -f video-all/index.html; mv video-all/"$NODE" video-all/index.html
./clean-up.pl download-all-video.log
