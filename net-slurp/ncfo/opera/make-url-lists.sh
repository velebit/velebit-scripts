#!/bin/sh
INDEX="${1-mp3/index.html}"
INDEX_PDF="${2-${INDEX}}"
INDEX_VIDEO="${3-${INDEX}}"

rm -f *.urllist

./extract-column-links.pl "$INDEX" \
    'Soprano Chorus MP3s' +0 'Meerkats' \
    | sed -e '/SopHi/d;/OldHi/d' > Katarina.mp3.urllist
./extract-column-links.pl "$INDEX" \
    'Soprano Chorus MP3s' +1 'All' \
    | sed -e '/SopHi/d;/OldHi/d' >> Katarina.mp3.urllist
./extract-column-links.pl "$INDEX" \
    'Soprano Chorus MP3s' +2 'Meerkats' \
    | sed -e '/SopHi/d;/OldHi/d' >> Katarina.mp3.urllist
./plinks.pl -t "$INDEX_VIDEO" \
    | sed -e '/\.mp4$/I!d;/^[^	]*chorus/I!d;s/^[^	]*	//' \
    > Katarina.video.urllist

./extract-column-links.pl "$INDEX" \
    'Bass Chorus MP3s' +0 'All' \
    | sed -e '/XXXnonesuchXXX/d' > bert.mp3.urllist
./extract-column-links.pl "$INDEX" \
    'Bass Chorus MP3s' +1 'All' \
    | sed -e '/XXXnonesuchXXX/d' >> bert.mp3.urllist
./extract-column-links.pl "$INDEX" \
    'Bass Chorus MP3s' +2 'All' \
    | sed -e '/XXXnonesuchXXX/d' >> bert.mp3.urllist
./plinks.pl -t "$INDEX_VIDEO" \
    | sed -e '/rain.*dance[^\/	]*\.mp4$/I!d;s/^[^	]*	//' \
    > bert.video.urllist

./extract-column-links.pl "$INDEX" \
    'Alto Chorus MP3s' +0 'All' \
    | sed -e '/XXXnonesuchXXX/d' > alto.mp3.urllist
./extract-column-links.pl "$INDEX" \
    'Alto Chorus MP3s' +1 'All' \
    | sed -e '/XXXnonesuchXXX/d' >> alto.mp3.urllist
./extract-column-links.pl "$INDEX" \
    'Alto Chorus MP3s' +2 'All' \
    | sed -e '/XXXnonesuchXXX/d' >> alto.mp3.urllist

./plinks.pl -h -t "$INDEX" \
    | sed -e '/\.mp3$/I!d;/^[^	]*demo/I!d;/complete	/Id;s/.*	//' \
    > demo.mp3.urllist

./plinks.pl "$INDEX_PDF" \
     | sed -e '/\.pdf$/I!d;/Score/!d' > score.pdf.urllist
