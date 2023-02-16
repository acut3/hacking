#!/usr/bin/python3
#
# Takes a list of domain names, and look for NS entries that don't  have an IP.
# It could indicate a potential zone takeover.
#

import sys
import json
import fileinput
import subprocess

from pathlib import Path


def status(msg):
    """
    Print status message on stderr.
    """
    print(f'[*] {msg}...', file=sys.stderr)


def compact_json(x):
    return json.dumps(x, separators=(',', ':'))


def massdns(hostnames, type='A'):
    """
    Run massdns on an interable of hostnames. Result is returned as an array of
    deserialized JSON objects.
    """
    res = None

    status(f'Querying {type} records for {len(hostnames)} names')

    p = subprocess.run(
        [
            'massdns',
            '-r', str(Path.home() / '.config/autorecon/resolvers.txt'),
            '-t', type,
            '-o', 'J',
        ],
        input='\n'.join(hostnames).encode(),
        capture_output=True,
    )

    if (p.returncode != 0):
        print(f'massdns error: {p.stderr.decode().strip()}', file=sys.stderr)
        sys.exit(1)
    else:
        res = [json.loads(s) for s in p.stdout.decode().split('\n') if s != '']

    return res


def parent_domains(indom):
    """
    Return a list of parent domains.
    parent_domains('aaa.bbb.ccc') -> ['aaa.bbb.ccc', 'bbb.ccc']
    """
    res = []
    components = indom.split('.')
    for i in range(0, len(components) - 1):
        res.append('.'.join(components[i:len(components)]))
    return res


def ns2zones(massdns_ns):
    """
    Given a massdns NS result, returns a dictionnary that maps each NS to the
    zones it's responsible for.
    """
    res = {}
    for query in massdns_ns:
        for answer in query['data'].get('answers', []):
            if answer['type'] == 'NS':
                ns = answer['data']
                res.setdefault(ns, []).append(query['name'])
    return res


def noip(massdns_a):
    """
    Given a massdns A result, returns a list of items that don't resolve to an
    IPv4.
    """
    res = []
    for query in massdns_a:
        resolves = False
        for answer in query['data'].get('answers', []):
            if answer['type'] == 'A' and answer['data'] != '':
                resolves = True
        if not resolves:
            res.append(query['name'])
    return res


def main():
    to_test = set()

    status('Generating list of parent domains...')
    for line in fileinput.input():
        to_test.update(parent_domains(line.strip()))

    massdns_ns = massdns(to_test, type='NS')
    print('hostname -> NS records:')
    print(compact_json(massdns_ns))

    hosts4ns = ns2zones(massdns_ns)
    print('NS -> hostnames:')
    print(compact_json(hosts4ns))

    massdns_a = massdns(hosts4ns.keys(), 'A')
    print('NS -> A records:')
    print(compact_json(massdns_a))

    ns_noip = noip(massdns_a)
    if len(ns_noip) == 0:
        print("No issues found")
    else:
        print("The following NS records don't have an A record:")
        for ns in ns_noip:
            print(f'* {ns}, responsible for resolving: '
                  + ' '.join(hosts4ns[ns]))


if __name__ == "__main__":
    main()
