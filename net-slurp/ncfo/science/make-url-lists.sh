#!/bin/sh
INDEX="${1-mp3/index.html}"
INDEX_PDF="${2-${INDEX}}"

DIR=urllists
rm -f *.urllist "$DIR"/*.urllist *.tmplist "$DIR"/*.tmplist
if [ ! -d "$DIR" ]; then mkdir "$DIR"; fi

### generate simple URL lists

FULL="$DIR/raw0.tmplist"
#./plinks.pl -b -pt -t "$INDEX" > "$FULL"
./plinks.pl -b -lt -t "$INDEX" > "$FULL"
for voice in soprano alto tenor bass; do
    LEVEL1="$DIR/raw1-$voice.tmplist"
    sed -e '/^'"$voice"'.*\.mp3$/I!d' \
	-e 's/^[^	]*	//' "$FULL" > "$LEVEL1"

    # just strip the line info
    LEVEL2="$DIR/raw2-$voice.tmplist"
    sed -e 's/^[^	]*	//' "$LEVEL1" > "$LEVEL2"

    for age in adults kids; do
	LEVEL3="$DIR/raw3-$voice.tmplist"
	case "$voice-$age" in
	    tenor-kids|bass-kids)
		      continue ;;
	    *-adults) skip=kids ;;
	    *-kids)   skip=adults ;;
	esac
	sed -e '/^'"$skip"'	/Id' \
	    -e 's/^[^	]*	//' "$LEVEL2" > "$LEVEL3"

	# OK, generate the URL list
	URLLIST="$DIR/$voice-$age-all.mp3.urllist"
	cp "$LEVEL3" "$URLLIST"
    done
done

sed -e '/^demo.*\.mp3$/I!d' \
    -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
    -e 's/^[^	]*	//' "$FULL" > "$DIR"/demo.mp3.urllist

#sed -e '/\.pdf$/I!d' \
#    -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
#    -e 's/^[^	]*	//' \
#    -e '/Score/!d' "$FULL" > "$DIR"/score.pdf.urllist

rm -f *.tmplist "$DIR"/*.tmplist

### generate generic URL lists

for age in adults kids; do
    va="soprano-$age"
    sed -e '/Medley\|Cosmic\|Laser\|Sky.*Dance/I{;/high/I!d;}' \
	-e '/Straight/{;/mezzo/Id;}' \
	-e '/Straight/{;/mezzo/Id;}' \
	"$DIR"/"$va"-all.mp3.urllist > "$DIR"/"$va"-high.mp3.urllist
    sed -e '/Medley\|Cosmic\|Laser\|Sky.*Dance/I{;/high/Id;}' \
	-e '/Straight/{;/mezzo/I!d;}' \
	"$DIR"/"$va"-all.mp3.urllist > "$DIR"/"$va"-low.mp3.urllist
done

for age in adults kids; do
    va="alto-$age"
    sed -e '/Medley\|Cosmic\|Laser\|Sky.*Dance/I{;/low/Id;}' \
	"$DIR"/"$va"-all.mp3.urllist > "$DIR"/"$va"-high.mp3.urllist
    sed -e '/Medley\|Cosmic\|Laser\|Sky.*Dance/I{;/low/I!d;}' \
	"$DIR"/"$va"-all.mp3.urllist > "$DIR"/"$va"-low.mp3.urllist
done

sed -e '/Laser\|Sky.*Dance/I{;/high/I!d;}' \
    "$DIR"/tenor-adults-all.mp3.urllist > "$DIR"/tenor-high.mp3.urllist
sed -e '/Laser\|Sky.*Dance/I{;/high/Id;}' \
    "$DIR"/tenor-adults-all.mp3.urllist > "$DIR"/tenor-low.mp3.urllist

sed -e '/Cosmic\|Sky.*Dance/I{;/low/Id;}' \
    -e '/Laser/I{;/high/I!d;}' \
    "$DIR"/bass-adults-all.mp3.urllist > "$DIR"/bass-high.mp3.urllist
# "mid" can go with either low or high in two-split songs:
sed -e '/Cosmic\|Sky.*Dance/I{;/low/Id;}' \
    -e '/Laser/I{;/mid/I!d;}' \
    "$DIR"/bass-adults-all.mp3.urllist > "$DIR"/bass-mid-hi.mp3.urllist
sed -e '/Cosmic\|Sky.*Dance/I{;/low/I!d;}' \
    -e '/Laser/I{;/mid/I!d;}' \
    "$DIR"/bass-adults-all.mp3.urllist > "$DIR"/bass-mid-lo.mp3.urllist
sed -e '/Cosmic\|Sky.*Dance/I{;/low/I!d;}' \
    -e '/Laser/I{;/low/I!d;}' \
    "$DIR"/bass-adults-all.mp3.urllist > "$DIR"/bass-low.mp3.urllist

### specific URL lists for our family

cp "$DIR"/soprano-kids-low.mp3.urllist Katarina+Luka.mp3.urllist

sed -e '/NothingForNow/Id' \
    "$DIR"/alto-adults-low.mp3.urllist > Abbe.mp3.urllist

sed -e '/NothingForNow/Id' \
    "$DIR"/tenor-low.mp3.urllist > bert.mp3.urllist
sed -e '/NothingForNow/I!d' \
    "$DIR"/bass-high.mp3.urllist >> bert.mp3.urllist

#sed -e '/Fingers/Id' \
#    "$DIR"/alto-adults-small.mp3.urllist > Abbe.mp3.urllist
#sed -ne '/Fingers/Ip' \
#    "$DIR"/tenor-adults-small.mp3.urllist >> Abbe.mp3.urllist
#
#sed -e '/Fingers/Id;/Bacteria/Id' \
#    "$DIR"/bass-adults-mob.mp3.urllist > bert.mp3.urllist
##sed -ne '/Fingers/Ip;/Bacteria/Ip' \
#sed -e '/Tamar/Id;/Moon/Id' \
#    "$DIR"/tenor-adults-mob.mp3.urllist >> bert.mp3.urllist

ln -s "$DIR"/demo.mp3.urllist demo.mp3.urllist
#ln -s "$DIR"/score.pdf.urllist score.pdf.urllist

## other people:

for vap in soprano-adults-low alto-adults-high; do
    file="$vap".mp3.urllist
    ln -s "$DIR"/"$file" X-"$file"
done

#for v in soprano alto; do
#    file="$v"-kids-mob.mp3.urllist
#    ln -s "$DIR"/"$file" X-"$file"
#done
#
#for v in soprano alto tenor bass; do
#    file="$v"-adults-mob.mp3.urllist
#    ln -s "$DIR"/"$file" X-"$file"
#done
#
#ln -s "$DIR"/alto-adults-small.mp3.urllist X-alto-adults-small.mp3.urllist
#
#cat "$DIR"/soprano-{kids,adults}-mob.mp3.urllist \
#    | sort | uniq > X-soprano-a+k-mob.mp3.urllist
#
#cat "$DIR"/{tenor,bass}-adults-mob.mp3.urllist \
#    | sort | uniq > X-tenor+bass-adults-mob.mp3.urllist
