<?php
include 'lib/log.php';

/* Log the request and optionnaly send a notification email
 *
 * The following URL parameters are accepted:
 * - email: send a notication email if set
 *
 * For example:
 * GET /log.php?who=victim.com&email
 */

$email = isset($_GET['email']) ? $_SERVER['ACUT3_EMAIL'] : NULL;
log_request($email);
?>
