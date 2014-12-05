#!/bin/sh
INDEX="${1-mp3/index.html}"
INDEX_PDF="${2-${INDEX}}"
INDEX_VIDEO="${3-${INDEX}}"

rm -f *.urllist

### Katarina (??? soprano I)
# MP3s
./extract-column-links.pl "$INDEX" \
    'Soprano Chorus MP3s' +0 'Jury Kids' \
    | sed -e '/Sop2/d;/Story/!{;/Encore/!d;}' > Katarina.mp3.urllist
./extract-column-links.pl "$INDEX" \
    'Soprano Chorus MP3s' +1 'Jury Kids' \
    | sed -e '/Sop2/d;/Story/!{;/Encore/!d;}' >> Katarina.mp3.urllist
## unstructured MP3 links following the table...
#./plinks.pl -b -pt -t -tl 1 "$INDEX" \
#    | sed -e '/\.mp3$/I!d' \
#          -e '/^Soprano/!d;s/^[^	]*	//' \
#          -e '/^[^	]*Meerkat/I!d;s/^[^	]*	//' \
#          -e '/[^	]*low/I!d;s/^[^	]*	//' >> Katarina.mp3.urllist
# video
./plinks.pl -h -t "$INDEX_VIDEO" \
    | sed -e '/^[^	]*VIDEO/I!d;s/^[^	]*	//' \
          -e '/^[^	]*chorus/I!d;s/^[^	]*	//' \
    > Katarina.video.urllist

### Abbe (??? alto)
# MP3s
./extract-column-links.pl "$INDEX" \
    'Soprano Chorus MP3s' +0 'Jury Kids' \
    | sed -e '/Sop2/d;/Story/!{;/Encore/!d;}' > Abbe.mp3.urllist
./extract-column-links.pl "$INDEX" \
    'Soprano Chorus MP3s' +1 'Jury Kids' \
    | sed -e '/XXXtextXXX/d;/Story/!{;/Encore/!d;}' >> Abbe.mp3.urllist

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
