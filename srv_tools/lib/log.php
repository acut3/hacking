<?php
function log_request($params = []) {
    $file  = $params['file']  ?? 'php.log';
    $email = $params['email'] ?? NULL;

    $data = '';

    # Client IP, HTTP user name, date
    $user = $_SERVER['PHP_AUTH_USER'] ?? '-';
    if ($user === '') {
        $user = '""';
    }
    $data .= "$_SERVER[REMOTE_ADDR] - $user " . date('[d/M/Y:H:i:s O]') . "\n";

    # Query
    $data .= "| $_SERVER[REQUEST_METHOD] $_SERVER[REQUEST_URI] $_SERVER[SERVER_PROTOCOL]\n";

    # Headers
    foreach (apache_request_headers() as $k => $v) {
            $data .= "| $k: $v\n";
    }
    $data .= "| \n";

    # Body
    $body = file_get_contents('php://input');
    if (strlen($body) > 0) {
        $data .= "| ";
        $data .= str_replace("\n", "\n| ", $body);
        $data .= "\n";
    }

    # Empty line between entries
    $data .= "\n";

    # Log request
    $file = basename($file);
    file_put_contents("/var/log/php/$file", $data, FILE_APPEND|LOCK_EX);

    # Notify be email
    if ($email) {
        mail($email, 'OOB hit', $data);
    }
}
?>
