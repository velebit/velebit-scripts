#!/bin/sh
INDEX="${1-mp3/index.html}"
INDEX_PDF="${2-${INDEX}}"
INDEX_VIDEO="${3-${INDEX}}"

rm -f *.urllist

./plinks.pl "$INDEX" \
    | sed -e 's:^,,/:../:' \
          -e '/\.mp3$/I!d;s,^\.\./,http://www.familyopera.org/drupal/,' \
    > all.mp3.urllist
./plinks.pl "$INDEX" \
    | sed -e 's:^,,/:../:' \
          -e '/\.zip$/I!d;s,^\.\./,http://www.familyopera.org/drupal/,' \
    > all.zip.urllist
