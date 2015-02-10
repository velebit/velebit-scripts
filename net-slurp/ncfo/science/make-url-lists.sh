#!/bin/sh
INDEX="${1-mp3/index.html}"
INDEX_PDF="${2-${INDEX}}"

DIR=urllists
rm -f *.urllist "$DIR"/*.urllist *.tmplist "$DIR"/*.tmplist
if [ ! -d "$DIR" ]; then mkdir "$DIR"; fi

FULL="$DIR/raw0.tmplist"
#./plinks.pl -b -pt -t "$INDEX" > "$FULL"
./plinks.pl -b -lt -t "$INDEX" > "$FULL"
for voice in soprano alto tenor bass; do
    LEVEL1="$DIR/raw1-$voice.tmplist"
    sed -e '/^'"$voice"'.*\.mp3$/I!d' \
	-e 's/^[^	]*	//' "$FULL" > "$LEVEL1"

#    for size in mob small; do
#	LEVEL2="$DIR/raw2-$voice-$size.tmplist"
#	case "$size" in
#	    mob)
#		sed -e '/^[^	]*small group/Id' \
#		    -e 's/^[^	]*	//' "$LEVEL1" > "$LEVEL2" ;;
#	    small)
#		sed -e 's/^[^	]*	//' "$LEVEL1" > "$LEVEL2" ;;
#	esac

    # just strip the line info
    LEVEL2="$DIR/raw2-$voice.tmplist"
    sed -e 's/^[^	]*	//' "$LEVEL1" > "$LEVEL2"

#	for age in kids adults; do
#	    case "$voice-$age" in
#		tenor-kids|bass-kids)  continue ;;
#	    esac
#	    LEVEL3="$DIR/raw3-$voice-$age-$size.tmplist"
#	    case "$age" in
#		kids)
#		    sed -e '/^[^	]*adults/Id' \
#			-e 's/^[^	]*	//' "$LEVEL2" > "$LEVEL3" ;;
#		adults)
#		    sed -e '/^[^	]*kids/Id' \
#			-e 's/^[^	]*	//' "$LEVEL2" > "$LEVEL3" ;;
#	    esac

    # just strip the link text info
    LEVEL3="$DIR/raw3-$voice.tmplist"
    sed -e 's/^[^	]*	//' "$LEVEL2" > "$LEVEL3"

    ### OK, generate the URL list
    URLLIST="$DIR/$voice-all.mp3.urllist"
    cp "$LEVEL3" "$URLLIST"

#	    ### OK, generate the URL list
#	    URLLIST="$DIR/$voice-$age-$size.mp3.urllist"
#	    cp "$LEVEL3" "$URLLIST"
#
#	    # program-specific fixups
#	    FIXLIST="$DIR/fix.tmplist"
#	    case "$age-$size" in
#		kids-small)
#		    sed -e '/string.*kids/Id' "URLLIST" > "$FIXLIST"
#		    mv "$FIXLIST" "$URLLIST"
#		    ;;
#	    esac
#	done
#    done

done
rm -f *.tmplist "$DIR"/*.tmplist

./plinks.pl -b "$INDEX" \
     | sed -e '/^demo.*\.mp3$/I!d;s/^[^	]*	//' > "$DIR"/demo.mp3.urllist

./plinks.pl "$INDEX" \
     | sed -e '/\.pdf$/I!d;/Score/!d' > "$DIR"/score.pdf.urllist

ln -s "$DIR"/soprano-all.mp3.urllist Katarina+Luka.mp3.urllist
ln -s "$DIR"/alto-all.mp3.urllist Abbe.mp3.urllist
ln -s "$DIR"/tenor-all.mp3.urllist bert.mp3.urllist

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
