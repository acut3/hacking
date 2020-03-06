#!/usr/bin/python3

wordlist = [ '1', '2', '3' ]
separators = [ '-', '_' ]


def combine(prefix, wl_index, n):

    if (n == 0):
        print(prefix)
        return

    sep = separators if len(prefix) > 0 else ['']

    for i in range(len(sep)):
        for j in range(len(wl_index)):
            combine(prefix + sep[i] + wordlist[wl_index[j]],
                    wl_index[0:j]+wl_index[j+1:],
                    n-1)

    pass


for i in range(1, len(wordlist)+1):
    combine('', list(range(len(wordlist))), i)

