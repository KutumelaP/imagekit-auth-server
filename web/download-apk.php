<?php
// APK Download Script
// This script serves the local APK file for download

// Check if APK file exists locally first
$local_apk = '../app-release.apk';
$local_apk_latest = '../app-release-latest.apk';
$web_apk = 'app-release.apk';

// Try to find the APK file
$apk_file = null;
if (file_exists($web_apk)) {
    $apk_file = $web_apk;
} elseif (file_exists($local_apk_latest)) {
    $apk_file = $local_apk_latest;
} elseif (file_exists($local_apk)) {
    $apk_file = $local_apk;
}

if ($apk_file && file_exists($apk_file)) {
    // Serve local APK file
    $file_size = filesize($apk_file);
    $file_name = 'OmniaSA-App.apk';
    
    // Set proper headers for APK download
    header('Content-Type: application/vnd.android.package-archive');
    header('Content-Disposition: attachment; filename="' . $file_name . '"');
    header('Content-Transfer-Encoding: binary');
    header('Content-Length: ' . $file_size);
    header('Cache-Control: must-revalidate');
    header('Pragma: public');
    header('Accept-Ranges: bytes');
    
    // Clear any output buffer
    if (ob_get_level()) {
        ob_end_clean();
    }
    
    // Read and output the file
    readfile($apk_file);
    exit;
} else {
    // Fallback: try GitHub download (latest from main branch)
    $github_url = 'https://github.com/KutumelaP/imagekit-auth-server/raw/main/app-release-latest.apk';
    
    // Set up cURL
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $github_url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
    curl_setopt($ch, CURLOPT_USERAGENT, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
    curl_setopt($ch, CURLOPT_TIMEOUT, 30);
    
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
    if ($http_code == 200 && $file_content !== false && strlen($file_content) > 1000) {
        // Set proper headers
        header('Content-Type: application/vnd.android.package-archive');
        header('Content-Disposition: attachment; filename="OmniaSA-App.apk"');
        header('Content-Transfer-Encoding: binary');
        header('Cache-Control: must-revalidate');
        header('Pragma: public');
        
        echo $file_content;
    } else {
        // Final fallback: show error
        header('Content-Type: text/html');
        echo '<!DOCTYPE html><html><head><title>Download Error</title></head><body>';
        echo '<h1>Download Error</h1>';
        echo '<p>Sorry, the APK file is not available at the moment. Please try again later.</p>';
        echo '<p><a href="download.html">← Back to Download Page</a></p>';
        echo '</body></html>';
    }
}
?>
