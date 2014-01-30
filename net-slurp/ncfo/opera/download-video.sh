#!/bin/sh
NODE=197
if [ -f video/index.html ]; then
    rm -f video/$NODE; mv video/index.html video/$NODE; fi
cp -p video/$NODE video/$NODE.orig
if ! wget --load-cookies cookies.txt \
    -nd -P video -N --progress=bar:force \
    http://www.familyopera.org/drupal/node/$NODE \
  > download-index.log 2>&1; then
    cat download-index.log
    rm -f video/index.html; mv video/$NODE.orig video/index.html
    exit 1
fi
cat download-index.log
rm -f video/$NODE.orig

rm -f video/index.html; mv video/$NODE video/index.html
./make-url-lists.sh video/index.html
sort *.video.urllist | uniq | sed -e '/\.[Mm][Pp]4/!d' > video-master.urllist
wget --load-cookies cookies.txt -i video-master.urllist \
    -nd -P video -N --restrict-file-names=windows \
    --progress=bar:force \
  2>&1 | tee download-video.log
rm -f video-master.urllist
./clean-up.pl download-video.log
