#!/bin/sh
wget --load-cookies cookies.txt \
    -A .pdf,.PDF,169 -nd -P pdf-all -N -r -l 1 --restrict-file-names=windows \
    --progress=bar:force \
    http://www.familyopera.org/drupal/node/169 \
  2>&1 | tee download-all-pdf.log
rm -f pdf-all/index.html; mv pdf-all/169 pdf-all/index.html
./clean-up.pl download-all-pdf.log
