#!/bin/sh
INDEX="${1-mp3/index.html}"
rm -f *.urllist
./extract-column-links.pl "$INDEX" \
    'Soprano Chorus MP3s' 'All' \
    | sed -e '/SopHi/d' > Katarina.mp3.urllist
# ...???... > Katarina.pdf.urllist

./extract-column-links.pl "$INDEX" \
    'Bass Chorus MP3s' 'All' \
    | sed -e '/XXXnonesuchXXX/d' > bert.mp3.urllist
# ...???... > bert.pdf.urllist

./extract-column-links.pl "$INDEX" \
    'Alto Chorus MP3s' 'All' \
    | sed -e '/XXXnonesuchXXX/d' > alto.mp3.urllist
# ...???... > alto.pdf.urllist
