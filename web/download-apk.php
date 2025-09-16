<?php
// APK Download Proxy Script
// This script proxies the APK download from GitHub to avoid browser warnings

header('Content-Type: application/vnd.android.package-archive');
header('Content-Disposition: attachment; filename="OmniaSA-App.apk"');
header('Content-Transfer-Encoding: binary');
header('Cache-Control: must-revalidate');
header('Pragma: public');

// GitHub release URL
$github_url = 'https://github.com/KutumelaP/imagekit-auth-server/releases/download/v1.0.0/app-release.apk';

// Set up cURL
$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $github_url);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
curl_setopt($ch, CURLOPT_USERAGENT, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');

// Get file size
curl_setopt($ch, CURLOPT_NOBODY, true);
curl_setopt($ch, CURLOPT_HEADER, true);
$headers = curl_exec($ch);
$file_size = curl_getinfo($ch, CURLINFO_CONTENT_LENGTH_DOWNLOAD);

// Set content length
if ($file_size > 0) {
    header('Content-Length: ' . $file_size);
}

// Reset cURL for actual download
curl_setopt($ch, CURLOPT_NOBODY, false);
curl_setopt($ch, CURLOPT_HEADER, false);

// Execute download
$file_content = curl_exec($ch);
$http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);

curl_close($ch);

// Check if download was successful
if ($http_code == 200 && $file_content !== false) {
    echo $file_content;
} else {
    // Fallback: redirect to GitHub
    header('Location: ' . $github_url);
    exit;
}
?>
