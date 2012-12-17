#!/bin/sh
rm -f *.urllist
./extract-column-links.pl mp3/index.html \
    'Black Ant Chorus Soprano:' 'Worker Ants' \
    | sed -e '/Sop_AC2/d' > Katarina.mp3.urllist
#./extract-column-links.pl mp3/index.html \
#    'Black Ant Chorus Soprano:' 'Worker Ants' \
#    | sed -e '/Sop_AC1/d' > soprano-left.mp3.urllist

./extract-column-links.pl mp3/index.html \
    'Black Ant Chorus Alto:' 'Worker Ants' \
    | sed -e '/Alto2/d' > Abbe.mp3.urllist
#./extract-column-links.pl mp3/index.html \
#    'Black Ant Chorus Alto:' 'Worker Ants' \
#    | sed -e '/Alto1/d' > alto-left.mp3.urllist

./extract-column-links.pl mp3/index.html \
    'Black Ant Chorus Alto C:' 'Worker Ants' \
    | sed -e '/Sop_AC2/d' > Meredith.mp3.urllist
#./extract-column-links.pl mp3/index.html \
#    'Black Ant Chorus Alto C:' 'Worker Ants' \
#    | sed -e '/Sop_AC1/d' > alto-c-left.mp3.urllist
