#!/bin/sh
wget --load-cookies cookies.txt \
    -A .pdf,.PDF -nd -P pdf -N -r -l 1 --restrict-file-names=windows \
    --progress=bar:force \
    http://www.familyopera.org/drupal/node/114 \
  2>&1 | tee download-pdf.log
./clean-up.pl download-pdf.log
