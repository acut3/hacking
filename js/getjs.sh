#!/usr/bin/bash

wget -xi -
find . -type f -exec js-beautify -r {} \;
