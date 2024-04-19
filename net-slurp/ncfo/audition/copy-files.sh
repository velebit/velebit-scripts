#!/bin/sh

if [ ! -e links.lst ]; then
    ~/scripts/net-slurp/plinks.pl -h -pt mp3/index.html > links.lst
fi

rm -rf ../Luka
mkdir ../Luka
cp -v \
`perl -ne '/Harmony Audition/||next;s/^[^\t]*\t//;/^Sop/||next;s,.*/,mp3/,;print' links.lst` \
../Luka

rm -rf ../Katarina
mkdir ../Katarina
cp -v \
`perl -ne '/Solo Audition/||next;s/^[^\t]*\t//;/^High Sop/||next;s,.*/,mp3/,;print' links.lst` \
`perl -ne '/Harmony Audition/||next;s/^[^\t]*\t//;/^Sop/||next;s,.*/,mp3/,;print' links.lst` \
../Katarina

rm -rf ../Abbe
mkdir ../Abbe
cp -v \
`perl -ne '/Solo Audition/||next;s/^[^\t]*\t//;/^Mezzo Sop/||next;s,.*/,mp3/,;print' links.lst` \
`perl -ne '/Harmony Audition/||next;s/^[^\t]*\t//;/^Alt/||next;s,.*/,mp3/,;print' links.lst` \
`perl -ne '/Harmony Audition/||next;s/^[^\t]*\t//;/^Ten/||next;s,.*/,mp3/,;print' links.lst` \
../Abbe

rm -rf ../bert
mkdir ../bert
cp -v \
`perl -ne '/Solo Audition/||next;s/^[^\t]*\t//;/^(?:...)?Bass/||next;s,.*/,mp3/,;print' links.lst` \
`perl -ne '/Harmony Audition/||next;s/^[^\t]*\t//;/^Ten/||next;s,.*/,mp3/,;print' links.lst` \
`perl -ne '/Harmony Audition/||next;s/^[^\t]*\t//;/^(?:...)?Bass/||next;s,.*/,mp3/,;print' links.lst` \
../bert
