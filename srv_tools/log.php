<?php
include 'etc/cfg.php';
include 'lib/log.php';

/* Log the request and optionnaly send a notification email
 *
 * The following URL parameters are accepted:
 * - email: send a notication email if set
 *
 * For example:
 * GET /log.php?who=victim.com&email
 */

$email = isset($_GET['email']) ? CFG_NOTIFICATION_EMAIL : NULL;
log_request(['email' => $email]);

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: *');
header('Access-Control-Allow-Headers: *');
?>
