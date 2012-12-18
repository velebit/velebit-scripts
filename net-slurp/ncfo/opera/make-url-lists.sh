#!/bin/sh
INDEX="${1-mp3/index.html}"
rm -f *.urllist
./extract-column-links.pl "$INDEX" \
    'Black Ant Chorus Soprano:' 'Worker Ants' \
    | sed -e '/Sop_AC2/d' > Katarina.mp3.urllist
#./extract-column-links.pl "$INDEX" \
#    'Black Ant Chorus Soprano:' 'Worker Ants' \
#    | sed -e '/Sop_AC1/d' > soprano-left.mp3.urllist
./extract-column-links.pl "$INDEX" \
    'Black Ant Chorus Soprano:' 'Click Song Name' \
    > Katarina.pdf.urllist

./extract-column-links.pl "$INDEX" \
    'Black Ant Chorus Alto:' 'Worker Ants' \
    | sed -e '/Alto2/d' > Abbe.mp3.urllist
#./extract-column-links.pl "$INDEX" \
#    'Black Ant Chorus Alto:' 'Worker Ants' \
#    | sed -e '/Alto1/d' > alto-left.mp3.urllist
./extract-column-links.pl "$INDEX" \
    'Black Ant Chorus Alto:' 'Click Song Name' \
    > Abbe.pdf.urllist

./extract-column-links.pl "$INDEX" \
    'Black Ant Chorus Alto C:' 'Worker Ants' \
    | sed -e '/Sop_AC2/d' > Meredith.mp3.urllist
#./extract-column-links.pl "$INDEX" \
#    'Black Ant Chorus Alto C:' 'Worker Ants' \
#    | sed -e '/Sop_AC1/d' > alto-c-left.mp3.urllist
./extract-column-links.pl "$INDEX" \
    'Black Ant Chorus Alto C:' 'Click Song Name' \
    > Meredith.pdf.urllist
