<?php
// PayFast ITN handler with signature verification and optional Firestore update
// Configure these values
$PAYFAST_PASSPHRASE   = 'PeterKutumela2025';   // must match PayFast dashboard
$FIREBASE_PROJECT_ID  = 'marketplace-8d6bd';   // your Firebase project id
$SERVICE_ACCOUNT_FILE = __DIR__ . '/serviceAccount.json'; // upload JSON here (do not commit to git)

$LOG_FILE = __DIR__ . '/payfast_itn.log';

// Helper: PHP-style urlencode for PayFast signature
function pfEncode($val) { return str_replace('%20', '+', urlencode($val)); }

// 1) Read POST safely
$data = $_POST;
if (!$data || !is_array($data)) { http_response_code(200); echo 'OK'; exit; }

// 2) Verify signature if passphrase set
function verify_signature(array $post, string $passphrase): bool {
  if (!isset($post['signature'])) return false;
  $received = strtolower(trim($post['signature']));
  unset($post['signature']);
  ksort($post);
  $sigString = '';
  foreach ($post as $k => $v) {
    if ($v === null || $v === '') continue;
    $sigString .= $k.'='.pfEncode($v).'&';
  }
  $sigString = rtrim($sigString, '&');
  if (!empty($passphrase)) { $sigString .= '&passphrase='.$passphrase; }
  $expected = md5($sigString);
  return $received === strtolower($expected);
}

// 3) Optional: check source IP (best-effort)
function is_valid_source_ip(): bool {
  // PayFast recommends DNS resolution, kept simple here
  $validHosts = ['www.payfast.co.za', 'sandbox.payfast.co.za'];
  $remote = $_SERVER['REMOTE_ADDR'] ?? '';
  foreach ($validHosts as $host) {
    $ips = gethostbynamel($host) ?: [];
    if (in_array($remote, $ips, true)) return true;
  }
  // If DNS check fails, do not block (to avoid dropping valid ITNs behind proxies)
  return true;
}

// 4) Log received data
@file_put_contents($LOG_FILE, date('c')."\n".print_r($data, true)."\n---\n", FILE_APPEND);

// 5) Validate
$sigOk = verify_signature($data, $PAYFAST_PASSPHRASE);
$ipOk  = is_valid_source_ip();
if (!$sigOk) {
  @file_put_contents($LOG_FILE, date('c')." SIGNATURE MISMATCH\n", FILE_APPEND);
  http_response_code(200); echo 'OK'; exit;
}
if (!$ipOk) {
  @file_put_contents($LOG_FILE, date('c')." IP CHECK FAILED\n", FILE_APPEND);
  http_response_code(200); echo 'OK'; exit;
}

// 6) Extract fields
$paymentStatus = strtoupper(trim($data['payment_status'] ?? ''));
$orderId       = $data['custom_str1'] ?? $data['m_payment_id'] ?? '';
$pfPaymentId   = $data['pf_payment_id'] ?? '';

// 7) If COMPLETE, update Firestore order to paid (optional if service account provided)
if ($paymentStatus === 'COMPLETE' && $orderId && file_exists($SERVICE_ACCOUNT_FILE)) {
  try {
    $svc = json_decode(file_get_contents($SERVICE_ACCOUNT_FILE), true);
    $token = get_google_access_token($svc, ['https://www.googleapis.com/auth/datastore']);
    if ($token) {
      firestore_mark_paid($FIREBASE_PROJECT_ID, $orderId, $pfPaymentId, $token);
    }
  } catch (Throwable $e) {
    @file_put_contents($LOG_FILE, date('c')." FIRESTORE_UPDATE_ERROR: ".$e->getMessage()."\n", FILE_APPEND);
  }
}

http_response_code(200);
echo 'OK';
exit;

// ===== Helpers: Google OAuth & Firestore REST =====
function b64url($data) { return rtrim(strtr(base64_encode($data), '+/', '-_'), '='); }

function get_google_access_token(array $svc, array $scopes): ?string {
  $header  = ['alg' => 'RS256', 'typ' => 'JWT'];
  $iat     = time();
  $exp     = $iat + 3600;
  $aud     = 'https://oauth2.googleapis.com/token';
  $payload = [
    'iss'   => $svc['client_email'],
    'scope' => implode(' ', $scopes),
    'aud'   => $aud,
    'exp'   => $exp,
    'iat'   => $iat,
  ];

  $toSign = b64url(json_encode($header)).'.'.b64url(json_encode($payload));
  $key    = openssl_pkey_get_private($svc['private_key']);
  $sig    = '';
  openssl_sign($toSign, $sig, $key, 'SHA256');
  $jwt    = $toSign.'.'.b64url($sig);

  $ch = curl_init($aud);
  curl_setopt_array($ch, [
    CURLOPT_POST => true,
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_HTTPHEADER => ['Content-Type: application/x-www-form-urlencoded'],
    CURLOPT_POSTFIELDS => http_build_query([
      'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      'assertion'  => $jwt,
    ]),
  ]);
  $res = curl_exec($ch);
  curl_close($ch);
  if (!$res) return null;
  $json = json_decode($res, true);
  return $json['access_token'] ?? null;
}

function firestore_mark_paid(string $projectId, string $orderId, string $pfPaymentId, string $token): void {
  $url = "https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/orders/".rawurlencode($orderId);
  $now = gmdate('Y-m-d\TH:i:s\Z');
  $body = [
    'fields' => [
      'payment' => [ 'mapValue' => [ 'fields' => [
        'method'  => ['stringValue' => 'payfast'],
        'gateway' => ['stringValue' => 'payfast'],
        'status'  => ['stringValue' => 'paid'],
        'pfPaymentId' => ['stringValue' => $pfPaymentId],
      ]]],
      'status'   => ['stringValue' => 'paid'],
      'paidAt'   => ['timestampValue' => $now],
      'updatedAt'=> ['timestampValue' => $now],
    ],
  ];

  $ch = curl_init($url.'?updateMask.fieldPaths=payment&updateMask.fieldPaths=status&updateMask.fieldPaths=paidAt&updateMask.fieldPaths=updatedAt');
  curl_setopt_array($ch, [
    CURLOPT_CUSTOMREQUEST => 'PATCH',
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_HTTPHEADER => [
      'Authorization: Bearer '.$token,
      'Content-Type: application/json',
    ],
    CURLOPT_POSTFIELDS => json_encode($body),
  ]);
  $res = curl_exec($ch);
  $http = curl_getinfo($ch, CURLINFO_HTTP_CODE);
  curl_close($ch);
  @file_put_contents(__DIR__.'/payfast_itn.log', date('c')." FIRESTORE_RESPONSE [$http]: $res\n", FILE_APPEND);
}


