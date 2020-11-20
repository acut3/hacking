#!/usr/bin/bash

wget --compression=gzip -xi -
find . -type f -exec js-beautify -r {} \;
