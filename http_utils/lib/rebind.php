<?php
# Update a DNS record. TTL is 0.
#
# Arguments:
#   - $name: name to update
#   - $addr: new IPv4 address
#
# Return value:
#   [
#     'rc'     => <return code from nsupdate command>
#     'stdout' => <stdout from nsupdate command>
#     'stderr' => <stderr from nsupdate command>
#   ]
#
# TSIG key must be defined in /etc/bind/rndc_www-data.key and readable by the
# httpd process (www-data user).
#
function rebind($name, $addr) {
    $rc = -1;
    $stdout = '';
    $stderr = '';

    $fdspec = [
        0 => ["pipe", "r"],
        1 => ["pipe", "w"],
        2 => ["pipe", "w"],
    ];

    $proc = proc_open(
        ['/usr/bin/nsupdate', '-k', '/etc/bind/rndc_www-data.key'],
        $fdspec, $pipes
    );

    if (is_resource($proc)) {
        $stdin = <<<EOT
del $name
add $name 0 IN A $addr
send
EOT;
        fwrite($pipes[0], $stdin);
        fclose($pipes[0]);

        $stdout = stream_get_contents($pipes[1]);
        fclose($pipes[1]);

        $stderr = stream_get_contents($pipes[2]);
        fclose($pipes[2]);

        $rc = proc_close($proc);
    }

    return ['rc' => $rc, 'stdout' => $stdout, 'stderr' => $stderr];
}
?>
