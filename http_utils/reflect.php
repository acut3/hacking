<?php
include 'lib/log.php';

/* Respond with the data specified in the URL.
 *
 * The following URL parameters are accepted:
 * - c: response status code
 * - h: response headers, specified in one of the following forms:
 *     - h=<header>
 *     - h[]=<header1>&h[]=<header2>
 *     - h[<name1>]=<value1>&h[<name2>]=<value2>
 * - b: reponse body
 *
 * For example:
 * GET /reflect.php?c=301&h[Location]=/
 */

// Log request
if (isset($_GET['l'])) {
    log_request();
}
// Send status code
if (NULL !== $code = $_GET['c'] ?? NULL) {
    http_response_code($code);
}
// Send headers
if (NULL !== $headers = $_GET['h'] ?? NULL) {
    if (is_array($headers)) {
        foreach ($headers as $key => $val) {
            if (is_string($key)) {
                header("$key: $val", FALSE);
            } elseif (is_int($key)) {
                header($val, FALSE);
            }
        }
    } else {
        header($headers);
    }
}
// Send body
if (NULL !== $body = $_GET['b'] ?? NULL) {
    echo $body;
}
?>
