#!/bin/sh

rm -f ../SfH\ Meredith\ practice.m3u
ln -s SfH\ X-MeredithGast\ practice.m3u  \
    ../SfH\ Meredith\ practice.m3u
./id3_tags.py SfH\ Meredith\ practice.m3u
rm -f ../SfH\ Meredith\ practice.m3u

rm -f ../SfH\ Erin+Sara\ practice.m3u
ln -s SfH\ X-ErinGast+SaraVerrilli\ practice.m3u \
    ../SfH\ Erin+Sara\ practice.m3u
./id3_tags.py SfH\ Erin+Sara\ practice.m3u
rm -f ../SfH\ Erin+Sara\ practice.m3u

rm -f ../Meredith+Erin+Sara.zip ../Meredith ../Erin+Sara
ln -s X-MeredithGast ../Meredith
ln -s X-ErinGast+SaraVerrilli ../Erin+Sara
(cd ..; zip Meredith+Erin+Sara.zip Meredith/* Erin+Sara/*)
rm -f ../Meredith ../Erin+Sara
