#!/bin/sh
wget --load-cookies cookies.txt \
    -A .pdf,.PDF,169 -nd -P pdf -N -r -l 1 --restrict-file-names=windows \
    --progress=bar:force \
    http://www.familyopera.org/drupal/node/169 \
  2>&1 | tee download-pdf.log
rm -f pdf/index.html; mv pdf/169 pdf/index.html
./clean-up.pl download-pdf.log
