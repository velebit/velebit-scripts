#!/bin/sh
NODE=175
DIR=pdf
LOG=download-pdf.log
if [ -f $DIR/index.html ]; then
    rm -f $DIR/$NODE.orig; mv $DIR/index.html $DIR/$NODE.orig
fi
rm -f $DIR/index.html $DIR/$NODE
wget --load-cookies cookies.txt \
    -A .pdf,.PDF,$NODE -R Brochure.pdf,Brochure-booklet.pdf \
    -nd -P $DIR -N -r -l 1 --restrict-file-names=windows \
    --progress=bar:force \
    http://www.familyopera.org/drupal/node/$NODE \
  2>&1 | tee $LOG
if [ -f $DIR/$NODE ]; then
    rm -f $DIR/index.html $DIR/$NODE.orig
    mv $DIR/$NODE $DIR/index.html
    ./clean-up.pl $LOG
elif [ -f $DIR/$NODE.orig ]; then
    rm -f $DIR/index.html $DIR/$NODE
    mv $DIR/$NODE.orig $DIR/index.html
    echo "(index not downloaded)"
else
    echo "(index not downloaded, original missing)"
fi
