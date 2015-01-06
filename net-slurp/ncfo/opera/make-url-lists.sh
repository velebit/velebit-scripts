#!/bin/sh
INDEX="${1-mp3/index.html}"
INDEX_PDF="${2-${INDEX}}"
INDEX_VIDEO="${3-${INDEX}}"

rm -f *.urllist

### Katarina (Jury Kids soprano I)
# MP3s
./extract-column-links.pl "$INDEX" \
    'Soprano Chorus MP3s' +0 'Jury Kids' \
    | sed -e '/Sop2/d' > Katarina.mp3.urllist
./extract-column-links.pl "$INDEX" \
    'Soprano Chorus MP3s' +1 'Jury Kids' \
    | sed -e '/Sop2/d' >> Katarina.mp3.urllist
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

### Abbe (Jury Kids alto)
# MP3s
./extract-column-links.pl "$INDEX" \
    'Alto Chorus MP3s' +0 'Jury Kids' \
    | sed -e '/XXXtextXXX/d' > Abbe.mp3.urllist
./extract-column-links.pl "$INDEX" \
    'Alto Chorus MP3s' +1 'Jury Kids' \
    | sed -e '/XXXtextXXX/d' >> Abbe.mp3.urllist

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

### generic Jury Kids soprano I MP3s
./extract-column-links.pl "$INDEX" \
    'Soprano Chorus MP3s' +0 'Jury Kids' \
    | sed -e '/Sop2/d' > 'Jury Kids soprano 1'.mp3.urllist
./extract-column-links.pl "$INDEX" \
    'Soprano Chorus MP3s' +1 'Jury Kids' \
    | sed -e '/Sop2/d' >> 'Jury Kids soprano 1'.mp3.urllist

### generic Jury Kids alto MP3s
./extract-column-links.pl "$INDEX" \
    'Alto Chorus MP3s' +0 'Jury Kids' \
    | sed -e '/XXXtextXXX/d' > 'Jury Kids alto'.mp3.urllist
./extract-column-links.pl "$INDEX" \
    'Alto Chorus MP3s' +1 'Jury Kids' \
    | sed -e '/XXXtextXXX/d' >> 'Jury Kids alto'.mp3.urllist

### generic Guards tenor MP3s
./extract-column-links.pl "$INDEX" \
    'Tenor and Bass Chorus MP3s' +0 'Security' | uniq \
    | sed -e '/Bass/I{;/TenBass/!d;};/GuardsLo/d;/ChorusLo/d;/DahsLo/d' \
    > 'Guards tenor all'.mp3.urllist
./extract-column-links.pl "$INDEX" \
    'Tenor and Bass Chorus MP3s' +1 'Security' | uniq \
    | sed -e '/Bass/I{;/TenBass/!d;};/GuardsLo/d;/ChorusLo/d;/DahsLo/d' \
    >> 'Guards tenor all'.mp3.urllist

### generic Guards bass MP3s
./extract-column-links.pl "$INDEX" \
    'Tenor and Bass Chorus MP3s' +0 'Security' | uniq \
    | sed -e '/Ten/I{;/TenBass/!d;};/GuardsHi/d;/ChorusHi/d;/DahsHi/d' \
    > 'Guards bass all'.mp3.urllist
./extract-column-links.pl "$INDEX" \
    'Tenor and Bass Chorus MP3s' +1 'Security' | uniq \
    | sed -e '/Ten/I{;/TenBass/!d;};/GuardsHi/d;/ChorusHi/d;/DahsHi/d' \
    >> 'Guards bass all'.mp3.urllist
