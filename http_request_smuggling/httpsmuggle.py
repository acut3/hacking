#!/usr/bin/python3
#
# Check if a URL is vulnerable to HTTP desync through HTTP request smuggling.
#

import argparse
import logging
import collections
import socket
import ssl
import urllib.parse


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('url')
    parser.add_argument('-v', '--verbose',
                        action='count', default=0,
                        help='increase output verbosity')
    args = parser.parse_args()

    # Configure logging
    if args.verbose == 0:
        level = logging.WARNING
    elif args.verbose == 1:
        level = logging.INFO
    else:
        level = logging.DEBUG
    logging.basicConfig(format='[%(levelname)s] %(message)s', level=level)

    return parser.parse_args()


def parse_url(url):
    '''Return the components of an http or https URL

    A named tuple is returned:
    - scheme: 'http' or 'https'
    - host: hostname (or IPv4/IPv6 address)
    - port
    - path: full path including any query or fragment

    A normalized URL can be formed as: scheme://host:port/path
    '''
    ParsedUrl = collections.namedtuple('ParsedURL',
                                       ['scheme', 'host', 'port', 'path'])
    if url[:7] != 'http://' and url[:8] != 'https://':
        url = 'http://' + url
    s = urllib.parse.urlsplit(url, scheme='http', allow_fragments=False)
    scheme = s.scheme
    host = s.hostname if s.hostname else s.netloc
    if s.port:
        port = s.port
    elif scheme == 'http':
        port = 80
    elif scheme == 'https':
        port = 443
    path = s.path if s.path else '/'
    if s.query:
        path += '?' + s.query
    return ParsedUrl(scheme, host, port, path)


def connect(target):
    '''Connect to a target as returned by parse_url()'''
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    if target.scheme == 'https':
        context = ssl.create_default_context()
        s = context.wrap_socket(sock, server_hostname=target.host)
    else:
        s = sock
    s.connect((target.host, target.port))
    return s


def is_vulnerable(target):
    s = connect(target)
    s.sendall(f'GET {target.path} HTTP/1.1\r\n\r\n'.encode())
    s.shutdown(socket.SHUT_RDWR)
    s.close()


def main():
    args = parse_args()
    target = parse_url(args.url)
    logging.debug(f'normalized url:'+
                  f'{target.scheme}://{target.host}:{target.port}{target.path}')
    is_vulnerable(target)


if __name__ == "__main__":
    main()
