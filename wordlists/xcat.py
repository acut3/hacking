#!/usr/bin/env python

import sys

def xcat(files, prefix=b''):
    if 0 == len(files):
        sys.stdout.buffer.write(prefix)
    else:
        prefix = prefix.rstrip(b'\r\n')
        for line in files[0]:
            xcat(files[1:], prefix + line)
        files[0].seek(0)

def main():
    try:
        files = [open(fname, 'rb') for fname in sys.argv[1:]]
    except OSError as e:
        print(f'{e.filename}: {e.strerror}', file=sys.stderr)
        sys.exit(1)

    xcat(files)

if __name__ == '__main__':
    main()
