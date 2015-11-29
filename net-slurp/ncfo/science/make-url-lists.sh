#!/bin/sh
INDEX="${1-mp3/index.html}"
INDEX_PDF="${2-${INDEX}}"

DIR=urllists
rm -f *.urllist "$DIR"/*.urllist *.tmplist "$DIR"/*.tmplist
if [ ! -d "$DIR" ]; then mkdir "$DIR"; fi

### generate simple URL lists

FULL="$DIR/raw0.tmplist"
#./plinks.pl -hb -pt -t "$INDEX" > "$FULL"
./plinks.pl -hb -lt -t "$INDEX" > "$FULL"
for voice in soprano alto tenor bass; do
    LEVEL1="$DIR/raw1-$voice.tmplist"
    sed -e '/^'"$voice"'.*\.mp3$/I!d' \
	-e 's/^[^	]*	//' "$FULL" > "$LEVEL1"

    # just strip the line info
    LEVEL2="$DIR/raw2-$voice.tmplist"
    sed -e 's/^[^	]*	//' "$LEVEL1" > "$LEVEL2"

    for age in adults kids; do
	LEVEL3="$DIR/raw3-$voice-$age.tmplist"
	case "$voice-$age" in
	    tenor-kids|bass-kids)
		continue ;;
	    *-adults) skip=kids ;;
	    *-kids)   skip=adults ;;
	esac
	sed -e '/^'"$skip"'	/Id' \
	    -e 's/^[^	]*	//' "$LEVEL2" > "$LEVEL3"

	for speed in "" "-slow"; do
	    # OK, generate the URL list
	    URLLIST="$DIR/$voice-$age-all$speed.mp3.urllist"
	    case "$speed" in
		"")
		    sed -e '/82/Id' "$LEVEL3" > "$URLLIST"
		    ;;
		-slow)
		    sed -e '/82/I!d' "$LEVEL3" > "$URLLIST"
		    ;;
	    esac
	done
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

for speed in "" "-slow"; do
    for age in adults kids; do
	va="soprano-$age"
	#sed -e '/Cosmic\|Laser\|Sky.*Dance/I{;/high/I!d;}' \
	sed -e '/Laser/I{;/high/I!d;}' \
	    -e '/Straight/{;/mezzo/Id;}' \
	    "$DIR"/"$va"-all"$speed".mp3.urllist \
	    > "$DIR"/"$va"-high"$speed".mp3.urllist
	sed -e '/Laser/I{;/high/Id;}' \
	    -e '/Straight/{;/mezzo/I!d;}' \
	    "$DIR"/"$va"-all"$speed".mp3.urllist \
	    > "$DIR"/"$va"-low"$speed".mp3.urllist
    done

    for age in adults kids; do
	va="alto-$age"
	sed -e '/Cosmic\|Laser/I{;/low/Id;}' \
	    "$DIR"/"$va"-all"$speed".mp3.urllist \
	    > "$DIR"/"$va"-high"$speed".mp3.urllist
	sed -e '/Cosmic\|Laser/I{;/low/I!d;}' \
	    "$DIR"/"$va"-all"$speed".mp3.urllist \
	    > "$DIR"/"$va"-low"$speed".mp3.urllist
    done

    sed -e '/Laser/I{;/high/I!d;}' \
	"$DIR"/tenor-adults-all"$speed".mp3.urllist \
	> "$DIR"/tenor-high"$speed".mp3.urllist
    sed -e '/Laser/I{;/high/Id;}' \
	"$DIR"/tenor-adults-all"$speed".mp3.urllist \
	> "$DIR"/tenor-low"$speed".mp3.urllist

    sed -e '/Cosmic/I{;/low/Id;}' \
	-e '/Laser/I{;/high/I!d;}' \
	"$DIR"/bass-adults-all"$speed".mp3.urllist \
	> "$DIR"/bass-high"$speed".mp3.urllist
    # "mid" can go with either low or high in two-split songs:
    sed -e '/Cosmic/I{;/low/Id;}' \
	-e '/Laser/I{;/mid/I!d;}' \
	"$DIR"/bass-adults-all"$speed".mp3.urllist \
	> "$DIR"/bass-mid-hi"$speed".mp3.urllist
    sed -e '/Cosmic/I{;/low/I!d;}' \
	-e '/Laser/I{;/mid/I!d;}' \
	"$DIR"/bass-adults-all"$speed".mp3.urllist \
	> "$DIR"/bass-mid-lo"$speed".mp3.urllist
    sed -e '/Cosmic/I{;/low/I!d;}' \
	-e '/Laser/I{;/low/I!d;}' \
	"$DIR"/bass-adults-all"$speed".mp3.urllist \
	> "$DIR"/bass-low"$speed".mp3.urllist
done

### specific URL lists for our family

for speed in "" "-slow"; do
    cp "$DIR"/soprano-kids-low"$speed".mp3.urllist \
	Katarina+Luka"$speed".mp3.urllist

    sed -e '/NothingForNow/Id' \
	"$DIR"/alto-adults-low"$speed".mp3.urllist > Abbe"$speed".mp3.urllist

    sed -e '/NothingForNow/Id' \
	"$DIR"/tenor-low"$speed".mp3.urllist > bert"$speed".mp3.urllist
    sed -e '/NothingForNow/I!d' \
	"$DIR"/bass-high"$speed".mp3.urllist >> bert"$speed".mp3.urllist
done

ln -s "$DIR"/demo.mp3.urllist demo.mp3.urllist
#ln -s "$DIR"/score.pdf.urllist score.pdf.urllist

## other people:

# X-... means don't bother updating the ID3 tags

other=
other="$other soprano-kids-high"
#other="$other soprano-kids-high-slow"
#other="$other soprano-kids-low"
#other="$other soprano-kids-low-slow"
#other="$other soprano-kids-all"
#other="$other soprano-kids-all-slow"
#other="$other soprano-adults-low"
#other="$other soprano-adults-low-slow"
#other="$other alto-adults-high"
#other="$other alto-adults-high-slow"
other="$other alto-adults-low"
other="$other alto-adults-low-slow"
other="$other alto-adults-all"
other="$other alto-adults-all-slow"

for vap in $other; do
    file="$vap".mp3.urllist
    ln -s "$DIR"/"$file" X-"$file"
done

other=
#other="$other soprano-kids-high"
#other="$other soprano-kids-high-slow"
#other="$other bass-high"
#other="$other bass-high-slow"

for vap in $other; do
    file="$vap".mp3.urllist
    ln -s "$DIR"/"$file" "$file"
done

diff "$DIR"/soprano-kids-{low,high}.mp3.urllist | sed -e '/^> /!d;s/^. //' \
    > soprano-kids-high-without-low.mp3.urllist
diff "$DIR"/{tenor-low,bass-high}.mp3.urllist | sed -e '/^> /!d;s/^. //' \
    > bass-high-without-tenor.mp3.urllist
