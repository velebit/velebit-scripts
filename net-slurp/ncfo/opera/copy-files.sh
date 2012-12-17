#!/bin/sh
./make-url-lists.sh
./urllist2process.pl *.mp3.urllist | ./process-files.pl
