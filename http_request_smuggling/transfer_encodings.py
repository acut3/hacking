# List of Transfer-Encoding headers to test
te_values = [
    'Transfer-Encoding: chunked',
    'Transfer-Encoding: chünked',
    'Transfer-Encoding: xchunked',
    'Transfer-Encoding : chunked',
    'Transfer-Encoding: chunked\r\nTransfer-Encoding: x',
    'Transfer-Encoding:\tchunked',
    ' Transfer-Encoding: chunked',
    'X: X\nTransfer-Encoding: chunked',
    'Transfer-Encoding\r\n: chunked',
]
