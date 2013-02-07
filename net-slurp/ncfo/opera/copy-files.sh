#!/bin/sh
./make-url-lists.sh
(./urllist2process.pl *.mp3.urllist; ./extras2process.pl mp3-extras.*) \
    | ./process-files.pl
