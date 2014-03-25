#!/bin/sh
INDEX="${1-mp3/index.html}"
INDEX_PDF="${2-${INDEX}}"
INDEX_VIDEO="${3-${INDEX}}"

rm -f *.urllist

### Katarina (young meerkat soprano II)
# MP3s
./extract-column-links.pl "$INDEX" \
    'Soprano Chorus MP3s' +0 'Meerkats' \
    | sed -e '/SopHi/d;/OldHi/d' > Katarina.mp3.urllist
./extract-column-links.pl "$INDEX" \
    'Soprano Chorus MP3s' +1 'All' \
    | sed -e '/SopHi/d;/OldHi/d' >> Katarina.mp3.urllist
./extract-column-links.pl "$INDEX" \
    'Soprano Chorus MP3s' +2 'Meerkats' \
    | sed -e '/SopHi/d;/OldHi/d' >> Katarina.mp3.urllist
# unstructured MP3 links following the table...
./plinks.pl -b -pt -t -tl 1 mp3/index.html \
    | sed -e '/\.mp3$/I!d' \
          -e '/^Soprano/!d;s/^[^	]*	//' \
          -e '/^[^	]*Meerkat/I!d;s/^[^	]*	//' \
          -e '/[^	]*low/I!d;s/^[^	]*	//' >> Katarina.mp3.urllist
# video
./plinks.pl -h -t "$INDEX_VIDEO" \
    | sed -e '/^[^	]*VIDEO/I!d;s/^[^	]*	//' \
          -e '/^[^	]*chorus/I!d;s/^[^	]*	//' \
    > Katarina.video.urllist

### bert (old water buffalo bass)
# MP3s
./extract-column-links.pl "$INDEX" \
    'Bass Chorus MP3s' +0 'All' \
    | sed -e '/XXXnonesuchXXX/d' > bert.mp3.urllist
./extract-column-links.pl "$INDEX" \
    'Bass Chorus MP3s' +1 'All' \
    | sed -e '/Iqhawe-bass\./Id' >> bert.mp3.urllist
./extract-column-links.pl "$INDEX" \
    'Bass Chorus MP3s' +2 'All' \
    | sed -e '/BassLo/Id' >> bert.mp3.urllist
# unstructured MP3 links following the table...
./plinks.pl -b -pt -t -tl 1 mp3/index.html \
    | sed -e '/\.mp3$/I!d' \
          -e '/^Bass/!d;s/^[^	]*	//' \
          -e '/^[^	]*Water Buffalo/I!d;s/^[^	]*	//' \
          -e 's/^[^	]*	//' >> bert.mp3.urllist
### video
./plinks.pl -h -t "$INDEX_VIDEO" \
    | sed -e '/^[^	]*VIDEO/I!d;s/^[^	]*	//' \
          -e '/^[^	]*chorus/I!d;s/^[^	]*	//' \
          -e '/rain.*dance[^\/]*$/I!d;s/^[^	]*	//' \
    > bert.video.urllist
./plinks.pl -h -t "$INDEX_VIDEO" \
    | sed -e '/^[^	]*VIDEO/I!d;s/^[^	]*	//' \
          -e '/^[^	]*chorus/I!d;s/^[^	]*	//' \
          -e '/scene.*7[^\/]*$/I!d;s/^[^	]*	//' \
    >> bert.video.urllist

### Extra: old gazelle alto
# MP3s
./extract-column-links.pl "$INDEX" \
    'Alto Chorus MP3s' +0 'All' \
    | sed -e '/XXXnonesuchXXX/d' > X-alto-gazelle.mp3.urllist
./extract-column-links.pl "$INDEX" \
    'Alto Chorus MP3s' +1 'All' \
    | sed -e '/XXXnonesuchXXX/d' >> X-alto-gazelle.mp3.urllist
./extract-column-links.pl "$INDEX" \
    'Alto Chorus MP3s' +2 'All' \
    | sed -e '/XXXnonesuchXXX/d' >> X-alto-gazelle.mp3.urllist
# unstructured MP3 links following the table...
./plinks.pl -b -pt -t -tl 1 mp3/index.html \
    | sed -e '/\.mp3$/I!d' \
          -e '/^Alto/!d;s/^[^	]*	//' \
          -e '/^[^	]*Gazelle/I!d;s/^[^	]*	//' \
          -e 's/^[^	]*	//' >> X-alto-gazelle.mp3.urllist

### Extra: old water buffalo tenor
# MP3s
./extract-column-links.pl "$INDEX" \
    'Tenor Chorus MP3s' +0 'All' \
    | sed -e '/XXXnonesuchXXX/d' > X-tenor-wbuff.mp3.urllist
./extract-column-links.pl "$INDEX" \
    'Tenor Chorus MP3s' +1 'All' \
    | sed -e '/XXXnonesuchXXX/Id' >> X-tenor-wbuff.mp3.urllist
./extract-column-links.pl "$INDEX" \
    'Tenor Chorus MP3s' +2 'All' \
    | sed -e '/XXXnonesuchXXX/Id' >> X-tenor-wbuff.mp3.urllist
# unstructured MP3 links following the table...
./plinks.pl -b -pt -t -tl 1 mp3/index.html \
    | sed -e '/\.mp3$/I!d' \
          -e '/^Tenor/!d;s/^[^	]*	//' \
          -e '/^[^	]*Water Buffalo/I!d;s/^[^	]*	//' \
          -e 's/^[^	]*	//' >> X-tenor-wbuff.mp3.urllist

### demo MP3s
./plinks.pl -h -t "$INDEX" \
    | sed -e '/\.mp3$/I!d;/^[^	]*demo/I!d;/complete	/Id;s/.*	//' \
    > demo.mp3.urllist

### orchestra-only MP3s
./plinks.pl -h -t "$INDEX" \
    | sed -e '/\.mp3$/I!d;/^[^	]*orchestra/I!d;/complete	/Id;s/.*	//' \
    > orchestra.mp3.urllist

### score PDFs
./plinks.pl "$INDEX_PDF" \
     | sed -e '/\.pdf$/I!d;/Score/!d' > score.pdf.urllist
