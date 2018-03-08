#!/bin/sh
INDEX="${1-mp3/index.html}"
INDEX_PDF="${2-${INDEX}}"

DIR=tmplists
rm -f *.urllist "$DIR"/*.urllist *.tmplist "$DIR"/*.tmplist \
     "$DIR"/*.page-lines "$DIR"/*.txt
if [ ! -d "$DIR" ]; then mkdir "$DIR"; fi

### generate simple URL lists

t='	'
c='[^'"$t"']'

FULL="$DIR/raw0.tmplist"
./plinks.pl -hb -lt -ll -t "$INDEX" \
    > "$FULL"
for voice in soprano alto tenor bass; do
    LEVEL1="$DIR/raw1-$voice.tmplist"
    sed -e '/^'"$voice"'.*\.mp3$/I!d' \
	-e 's/^'"$c*$t"'//' \
	"$FULL" > "$LEVEL1"

    for split in '' -low -high -all; do
	LEVEL2="$DIR/raw2-$voice$split.tmplist"

	skip_split=''; skip_harm=''
	case "$voice$split" in
	    soprano|alto|tenor-*|bass-*)
		continue ;;
	    soprano-high) skip_split='\(low\|middle\)' ;;
	    soprano-low)  skip_split='\(high\)' ;;
	    alto-high)    skip_split='\(low\)'; skip_harm='middle' ;;
	    alto-low)     skip_split='\(middle\|high\)'; skip_harm='high'  ;;
	esac
	if [ -n "$skip_split" ]; then
	    skip='\('"$skip_split split"'\|'"step $skip_split"
	    if [ -n "$skip_harm" ]; then
		skip="$skip"'\|'"$skip_harm harmony"
	    fi
	    #skip="$skip"'\|last note F'
	    skip="$skip"'\)'
	    sed -e '/^'"$c*$t$c*$t$c*$skip"'/Id' \
		"$LEVEL1" > "$LEVEL2"
	else
	    sed -e ':dummy' \
		"$LEVEL1" > "$LEVEL2"
	fi

	for age in adults kids all; do
	    LEVEL3="$DIR/raw3-$voice$split-$age.tmplist"

	    kids_regex='\(kids\|melody\)'
	    case "$voice-$age" in
		tenor-kids|tenor-all|bass-kids|bass-all)
		    continue ;;
		*-adults)
		    sed -e '/^'"$c*$kids_regex$c*$t"'[^1]/{' \
			-e '/^'"$c*$t$c*$t$c*$kids_regex"'/Id' \
			-e '}' \
			"$LEVEL2" > "$LEVEL3"
		    ;;
		*-kids)
		    sed -e '/^'"$c*$kids_regex$c*$t"'[^1]/{' \
			-e '/^'"$c*$t$c*$t$c*$kids_regex"'/I!d' \
			-e '}' \
			"$LEVEL2" > "$LEVEL3"
		    ;;
		*-all)
		    cat \
			"$LEVEL2" > "$LEVEL3"
		    ;;
		*)  echo "***ERROR***"; exit 1 ;;
	    esac

	    #for speed in "" "-slow"; do

	    # Keep a list of lines from the HTML file for CD case generation
	    LINES="$DIR/page_lines.$voice$split-$age.txt"
	    sed -e 's/'"$t"'.*//' \
		"$LEVEL3" > "$LINES"

	    # That's all, folks!
	    URLLIST="$DIR/$voice$split-$age.mp3.urllist"
	    sed -e 's/^'"$c*$t"'//' \
		-e 's/^'"$c*$t"'//' \
		-e 's/^'"$c*$t"'//' \
		"$LEVEL3" > "$URLLIST"
	done
    done
done

sed -e '/^demo.*\.mp3$/I!d' \
    -e 's/^'"$c*$t"'//' -e 's/^'"$c*$t"'//' \
    -e 's/^'"$c*$t"'//' -e 's/^'"$c*$t"'//' "$FULL" > "$DIR"/demo.mp3.urllist
sed -e '/^demo.*\.mp3$/I!d' \
    -e 's/^'"$c*$t"'//' \
    -e 's/'"$t"'.*//' "$FULL" > "$DIR"/page_lines.demo.txt

sed -e '/^soloist.*\.mp3$/I!d' \
    -e 's/^'"$c*$t"'//' -e 's/^'"$c*$t"'//' \
    -e 's/^'"$c*$t"'//' -e 's/^'"$c*$t"'//' "$FULL" > "$DIR"/solo.mp3.urllist
sed -e '/^soloist.*\.mp3$/I!d' \
    -e 's/^'"$c*$t"'//' \
    -e 's/'"$t"'.*//' "$FULL" > "$DIR"/page_lines.solo.txt

sed -e '/^\(piano\|orchestra\).*\.mp3$/I!d' \
    -e 's/^'"$c*$t"'//' -e 's/^'"$c*$t"'//' \
    -e 's/^'"$c*$t"'//' -e 's/^'"$c*$t"'//' "$FULL" \
    > "$DIR"/orchestra.mp3.urllist
sed -e '/^\(piano\|orchestra\).*\.mp3$/I!d' \
    -e 's/^'"$c*$t"'//' \
    -e 's/'"$t"'.*//' "$FULL" > "$DIR"/page_lines.orchestra.txt

#sed -e '/\.pdf$/I!d' \
#    -e 's/^'"$c*$t"'//' -e 's/^'"$c*$t"'//' \
#    -e 's/^'"$c*$t"'//' \
#    -e '/Score/!d' "$FULL" > "$DIR"/score.pdf.urllist

if [ ! -e .tmplist.keep ]; then
    rm -f *.tmplist "$DIR"/*.tmplist
fi

### specific URL lists for our family

sed -e '/NothingForNow/Id' \
    "$DIR"/soprano-high-kids.mp3.urllist > Katarina+Luka.mp3.urllist
#sed -e '1,/AnnieJumpCannon/!d' \
#    "$DIR"/soprano-high-kids.mp3.urllist > Katarina+Luka.mp3.urllist
#sed -e '/AnnieJumpCannon/!d' \
#    "$DIR"/solo.mp3.urllist >> Katarina+Luka.mp3.urllist
#sed -e '1,/AnnieJumpCannon/d' \
#    "$DIR"/soprano-high-kids.mp3.urllist >> Katarina+Luka.mp3.urllist

sed -e '/NothingForNow/Id' \
    "$DIR"/alto-low-adults.mp3.urllist > Abbe.mp3.urllist

sed -e '/Water.*Bear/I,$d' \
    "$DIR"/tenor-adults.mp3.urllist > bert.mp3.urllist
sed -e '/Water.*Bear.*high/I!d' \
    "$DIR"/bass-adults.mp3.urllist >> bert.mp3.urllist


ln -s "$DIR"/demo.mp3.urllist demo.mp3.urllist
#ln -s "$DIR"/score.pdf.urllist score.pdf.urllist

## other people:
# (X-... means don't bother updating the ID3 tags)

other=
#other="$other soprano-all-all"
#other="$other soprano-high-kids"
#other="$other soprano-high-adults"
#other="$other soprano-low-kids"
#other="$other soprano-low-adults"
#other="$other alto-all-all"
#other="$other alto-high-kids"
#other="$other alto-high-adults"
#other="$other alto-low-kids"
#other="$other alto-low-adults"
#other="$other tenor-adults"
#other="$other bass-adults"
other="$other orchestra"

for vap in $other; do
    file="$vap".mp3.urllist
    ln -s "$DIR"/"$file" X-"$file"
done

#diff "$DIR"/{tenor-low,bass-high}.mp3.urllist | sed -e '/^> /!d;s/^. //' \
#    > bass-high-without-tenor.mp3.urllist
