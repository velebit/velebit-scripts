#!/bin/sh
NODE=197
wget --load-cookies cookies.txt \
    -A .pdf,.PDF,"$NODE" -nd -P pdf-all -N -r -l 1 \
    --restrict-file-names=windows \
    --progress=bar:force \
    http://www.familyopera.org/drupal/node/"$NODE" \
  2>&1 | tee download-all-pdf.log
rm -f pdf-all/index.html; mv pdf-all/"$NODE" pdf-all/index.html
./clean-up.pl download-all-pdf.log
