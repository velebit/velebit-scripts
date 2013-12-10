#!/bin/sh
INDEX="${1-mp3/index.html}"
rm -f *.urllist
./extract-column-links.pl "$INDEX" \
    'Soprano Chorus MP3s' +0 'All' \
    | sed -e '/SopHi/d' > Katarina.mp3.urllist
./extract-column-links.pl "$INDEX" \
    'Soprano Chorus MP3s' +1 'All' \
    | sed -e '/SopHi/d' >> Katarina.mp3.urllist

./extract-column-links.pl "$INDEX" \
    'Bass Chorus MP3s' +0 'All' \
    | sed -e '/XXXnonesuchXXX/d' > bert.mp3.urllist
./extract-column-links.pl "$INDEX" \
    'Bass Chorus MP3s' +1 'All' \
    | sed -e '/XXXnonesuchXXX/d' >> bert.mp3.urllist

./extract-column-links.pl "$INDEX" \
    'Alto Chorus MP3s' +0 'All' \
    | sed -e '/XXXnonesuchXXX/d' > alto.mp3.urllist
./extract-column-links.pl "$INDEX" \
    'Alto Chorus MP3s' +1 'All' \
    | sed -e '/XXXnonesuchXXX/d' >> alto.mp3.urllist
