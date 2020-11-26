#!/usr/bin/bash

wget --no-check-certificate --compression=gzip -xi -
find . -type f -exec js-beautify -r {} \;
