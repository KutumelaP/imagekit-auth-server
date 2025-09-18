import 'dart:io';
import 'dart:convert';

void main() async {
  try {
    // Read pubspec.yaml to get current version
    final pubspecFile = File('pubspec.yaml');
    final pubspecContent = await pubspecFile.readAsString();
    
    // Extract version line
    final versionRegex = RegExp(r'^version:\s*(.+)$', multiLine: true);
    final versionMatch = versionRegex.firstMatch(pubspecContent);
    
    if (versionMatch == null) {
      print('❌ Could not find version in pubspec.yaml');
      exit(1);
    }
    
    final version = versionMatch.group(1)!.trim();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    print('📱 Updating cache version to: $version');
    print('🕒 Build timestamp: $timestamp');
    
    // Update service worker
    await updateServiceWorker(version, timestamp);
    
    // Update index.html meta tag
    await updateIndexHtml(version);
    
    // Update cache management service
    await updateCacheManagementService(version);
    
    print('✅ Cache version updated successfully!');
    
  } catch (e) {
    print('❌ Error updating cache version: $e');
    exit(1);
  }
}

Future<void> updateServiceWorker(String version, int timestamp) async {
  final swFile = File('web/flutter_service_worker.js');
  
  if (!await swFile.exists()) {
    print('⚠️ Service worker file not found, skipping...');
    return;
  }
  
  var content = await swFile.readAsString();
  
  // Update APP_VERSION
  content = content.replaceAll(
    RegExp(r"const APP_VERSION = '[^']*';"),
    "const APP_VERSION = '$version';"
  );
  
  // Update BUILD_TIMESTAMP
  content = content.replaceAll(
    RegExp(r'const BUILD_TIMESTAMP = \d+;'),
    'const BUILD_TIMESTAMP = $timestamp;'
  );
  
  await swFile.writeAsString(content);
  print('✅ Updated service worker with version $version');
}

Future<void> updateIndexHtml(String version) async {
  final indexFile = File('web/index.html');
  
  if (!await indexFile.exists()) {
    print('⚠️ index.html not found, skipping...');
    return;
  }
  
  var content = await indexFile.readAsString();
  
  // Add or update app version meta tag
  if (content.contains('name="app-version"')) {
    content = content.replaceAll(
      RegExp(r'<meta name="app-version" content="[^"]*"'),
      '<meta name="app-version" content="$version"'
    );
  } else {
    // Add meta tag after existing meta tags
    content = content.replaceFirst(
      '</head>',
      '  <meta name="app-version" content="$version" />\n</head>'
    );
  }
  
  // Add cache-busting query parameter to main.dart.js
  content = content.replaceAll(
    RegExp(r'main\.dart\.js(\?[^"]*)?'),
    'main.dart.js?v=$version'
  );
  
  await indexFile.writeAsString(content);
  print('✅ Updated index.html with version $version');
}

Future<void> updateCacheManagementService(String version) async {
  final serviceFile = File('lib/services/cache_management_service.dart');
  
  if (!await serviceFile.exists()) {
    print('⚠️ Cache management service not found, skipping...');
    return;
  }
  
  var content = await serviceFile.readAsString();
  
  // Add version constant if not exists
  if (!content.contains('static const String APP_VERSION')) {
    content = content.replaceFirst(
      'class CacheManagementService {',
      'class CacheManagementService {\n  static const String APP_VERSION = \'$version\';'
    );
  } else {
    // Update existing version
    content = content.replaceAll(
      RegExp(r"static const String APP_VERSION = '[^']*';"),
      "static const String APP_VERSION = '$version';"
    );
  }
  
  await serviceFile.writeAsString(content);
  print('✅ Updated cache management service with version $version');
}
