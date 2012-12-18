#!/bin/sh
NODE=169
if [ -f mp3/index.html ]; then rm -f mp3/$NODE; mv mp3/index.html mp3/$NODE; fi
wget --load-cookies cookies.txt \
    -nd -P mp3 -N --progress=bar:force \
    http://www.familyopera.org/drupal/node/$NODE \
  2>&1 | tee download-index.log
rm -f mp3/index.html; mv mp3/$NODE mp3/index.html
./make-url-lists.sh mp3/index.html
sort *.mp3.urllist | uniq | sed -e '/\.[Mm][Pp]3$/!d' > mp3-master.urllist
wget --load-cookies cookies.txt -i mp3-master.urllist \
    -nd -P mp3 -N --restrict-file-names=windows \
    --progress=bar:force \
  2>&1 | tee download.log
rm -f mp3-master.urllist
./clean-up.pl download.log
