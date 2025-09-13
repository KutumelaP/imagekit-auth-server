<?php
// Minimal ITN logger for now. We can enhance to verify signature and update Firestore later.
$logFile = __DIR__ . '/payfast_itn.log';
file_put_contents($logFile, date('c')."\n".print_r($_POST,true)."\n---\n", FILE_APPEND);
http_response_code(200);
echo 'OK';


