<?php
// CONFIG
$MERCHANT_ID = '23918934';
$MERCHANT_KEY = 'fxuj8ymlgqwra';
$PASSPHRASE  = 'PeterKutumela2025'; // keep private
$ENFORCE_SIGNATURE = false; // set true after confirming matching signatures in PayFast
$TARGET      = (isset($_GET['sandbox']) && $_GET['sandbox'] === 'true')
  ? 'https://sandbox.payfast.co.za/eng/process'
  : 'https://www.payfast.co.za/eng/process';

// Helper: PHP-style urlencode for signature
function pfEncode($val) {
  return str_replace('%20', '+', urlencode($val));
}

// Collect fields (allowlist)
$allowed = [
  'merchant_id','merchant_key','return_url','cancel_url','notify_url',
  'amount','item_name','item_description','email_address','name_first','name_last','cell_number',
  'custom_str1','custom_str2','custom_str3','custom_str4','custom_str5'
];
$data = array_merge($_GET, $_POST);
$postData = [];
foreach ($allowed as $k) {
  if (isset($data[$k]) && $data[$k] !== '') {
    $postData[$k] = $data[$k];
  }
}

// Required fallbacks
if (!isset($postData['merchant_id'])) { $postData['merchant_id'] = $MERCHANT_ID; }
if (!isset($postData['merchant_key'])) { $postData['merchant_key'] = $MERCHANT_KEY; }
if (empty($postData['name_first'])) { $postData['name_first'] = 'Customer'; }
if (empty($postData['name_last']))  { $postData['name_last']  = 'Customer'; }
if (empty($postData['item_description']) && !empty($postData['item_name'])) {
  $postData['item_description'] = $postData['item_name'];
}
if (empty($postData['cell_number'])) { $postData['cell_number'] = '0606304683'; }

// Optional signature (disabled by default to avoid 400 until verified)
if ($ENFORCE_SIGNATURE) {
  ksort($postData);
  $signatureString = '';
  foreach ($postData as $k => $v) {
    $signatureString .= $k.'='.pfEncode($v).'&';
  }
  $signatureString = rtrim($signatureString, '&');
  if (!empty($PASSPHRASE)) {
    $signatureString .= '&passphrase='.$PASSPHRASE; // per PayFast docs: raw append
  }
  $signature = md5($signatureString);
  $postData['signature'] = $signature;
}

// Output auto-submit HTML form
?>
<!doctype html>
<html><head><meta charset="utf-8"><title>Redirecting…</title></head>
<body style="font-family:Arial;padding:40px;text-align:center;">
  <h2>Redirecting to PayFast…</h2>
  <form id="pf" method="post" action="<?php echo htmlspecialchars($TARGET); ?>">
    <?php foreach ($postData as $k => $v): ?>
      <input type="hidden" name="<?php echo htmlspecialchars($k); ?>" value="<?php echo htmlspecialchars($v); ?>">
    <?php endforeach; ?>
    <button type="submit" style="padding:10px 20px;">Continue</button>
  </form>
  <script>setTimeout(function(){document.getElementById('pf').submit();},150);</script>
</body></html>


