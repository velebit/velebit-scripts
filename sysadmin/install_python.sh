#!/bin/sh

py_install='pip3 install --disable-pip-version-check'

$py_install \
    scipy numpy matplotlib \
    unidecode
