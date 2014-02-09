#!/bin/sh
#PAGE_DIR=node/175
PAGE_DIR=2014_Powers_of_Ten_Lyrics_and_Sheet_Music
PAGE_FILE="`basename "$PAGE_DIR"`"
DIR=pdf
LOG=download-pdf.log
if [ -f $DIR/index.html ]; then
    rm -f $DIR/$PAGE_FILE.orig; mv $DIR/index.html $DIR/$PAGE_FILE.orig
fi
rm -f $DIR/index.html $DIR/$PAGE_FILE
wget --load-cookies cookies.txt \
    -A .pdf,.PDF,$PAGE_FILE -R Brochure-FINAL.pdf,Brochure-booklet.pdf \
    -nd -P $DIR -N -r -l 1 --restrict-file-names=windows \
    --progress=bar:force \
    http://www.familyopera.org/drupal/"$PAGE_DIR" \
  2>&1 | tee $LOG
if [ -f $DIR/$PAGE_FILE ]; then
    rm -f $DIR/index.html $DIR/$PAGE_FILE.orig
    mv $DIR/$PAGE_FILE $DIR/index.html
    ./clean-up.pl $LOG
elif [ -f $DIR/$PAGE_FILE.orig ]; then
    rm -f $DIR/index.html $DIR/$PAGE_FILE
    mv $DIR/$PAGE_FILE.orig $DIR/index.html
    echo "(index not downloaded)"
else
    echo "(index not downloaded, original missing)"
fi
