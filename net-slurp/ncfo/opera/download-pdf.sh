#!/bin/sh
NODE=169
if [ -f pdf/index.html ]; then rm -f pdf/$NODE; mv pdf/index.html pdf/$NODE; fi
cp -p pdf/$NODE pdf/$NODE.orig
if ! wget --load-cookies cookies.txt \
    -nd -P pdf -N --progress=bar:force \
    http://www.familyopera.org/drupal/node/$NODE \
  > download-index.log 2>&1; then
    cat download-index.log
    rm -f pdf/index.html; mv pdf/$NODE.orig pdf/index.html
    exit 1
fi
cat download-index.log
rm -f pdf/$NODE.orig

rm -f pdf/index.html; mv pdf/$NODE pdf/index.html
./make-url-lists.sh pdf/index.html
sort *.pdf.urllist | uniq | sed -e '/\.[Pp][Dd][Ff]$/!d' > pdf-master.urllist
wget --load-cookies cookies.txt -i pdf-master.urllist \
    -nd -P pdf -N --restrict-file-names=windows \
    --progress=bar:force \
  2>&1 | tee download-pdf.log
rm -f pdf-master.urllist
./clean-up.pl download-pdf.log
