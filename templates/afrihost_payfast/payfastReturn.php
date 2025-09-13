<?php
$orderId = isset($_GET['order_id']) ? $_GET['order_id'] : '';
?>
<!doctype html>
<html><head><meta charset="utf-8"><title>Payment Success</title></head>
<body style="font-family:Arial;padding:40px;text-align:center;">
  <h2>Payment received</h2>
  <p>Thank you! You can close this window and return to the app.</p>
  <?php if ($orderId): ?><p>Order: <?php echo htmlspecialchars($orderId); ?></p><?php endif; ?>
</body></html>


