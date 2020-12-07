#!/usr/bin/bash
#
# Download and beautify URLs passed on stdin.
# All arguments are passed to the wget command.
#
# Example:
# getjs.sh --header='Cookie: ...' < urls.txt
#

# Download files
wget "$@" --no-check-certificate --compression=gzip -x -i -

# Beautify them
find . -type f | while read f
do
    ftype='js'

    # Files that don't end with .js and that have '<' as their first non-blank
    # character are HTML
    echo "$f" | grep -vqE '\.js(\?)?' &&
        [[ `sed '/\S/{s/\s*\(.\).*/\1/;q};d' "$f"` = '<' ]] &&
        ftype='html'

    printf '[%4s] ' "$ftype"

    # Remove any leading space on first line
    sed -i '1s/^\s*//' "$f"
    # Beautify file
    js-beautify --type "$ftype" -r "$f"
done
