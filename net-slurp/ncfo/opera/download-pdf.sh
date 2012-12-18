#!/bin/sh
NODE=169
if [ -f pdf/index.html ]; then rm -f pdf/$NODE; mv pdf/index.html pdf/$NODE; fi
wget --load-cookies cookies.txt \
    -nd -P pdf -N --progress=bar:force \
    http://www.familyopera.org/drupal/node/$NODE \
  2>&1 | tee download-index.log
rm -f pdf/index.html; mv pdf/$NODE pdf/index.html
./make-url-lists.sh pdf/index.html
sort *.pdf.urllist | uniq | sed -e '/\.[Pp][Dd][Ff]$/!d' > pdf-master.urllist
wget --load-cookies cookies.txt -i pdf-master.urllist \
    -nd -P pdf -N --restrict-file-names=windows \
    --progress=bar:force \
  2>&1 | tee download-pdf.log
rm -f pdf-master.urllist
./clean-up.pl download-pdf.log
