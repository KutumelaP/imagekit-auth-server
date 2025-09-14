import 'package:flutter/foundation.dart';
import 'package:omniasa/utils/web_js_stub.dart'
    if (dart.library.html) 'package:omniasa/utils/web_js_real.dart' as js;

class WebEnv {
  static bool get isWeb => kIsWeb;

  static bool get isIOSWeb {
    if (!kIsWeb) return false;
    try {
      final ua = js.context.callMethod('eval', ['navigator.userAgent']) as String?;
      final platform = js.context.callMethod('eval', ['navigator.platform']) as String?;
      final maxTouch = js.context.callMethod('eval', ['navigator.maxTouchPoints'])?.toString();
      final iosUA = (ua ?? '').contains('iPhone') || (ua ?? '').contains('iPad') || (ua ?? '').contains('iPod');
      final isTouchMac = (platform ?? '') == 'MacIntel' && (int.tryParse(maxTouch ?? '0') ?? 0) > 1;
      return iosUA || isTouchMac;
    } catch (_) {
      return false;
    }
  }

  static bool get isStandalonePWA {
    if (!kIsWeb) return false;
    try {
      final match = js.context.callMethod('eval', [
        "(window.matchMedia && window.matchMedia('(display-mode: standalone)').matches) ? '1' : '0'"
      ]);
      final standalone = match == '1';
      final navigatorStandalone = js.context.hasProperty('navigator') && js.context['navigator'].hasProperty('standalone') && js.context['navigator']['standalone'] == true;
      return standalone || navigatorStandalone;
    } catch (_) {
      return false;
    }
  }

  static bool get hasNotificationApi {
    if (!kIsWeb) return false;
    try { return js.context.hasProperty('Notification'); } catch (_) { return false; }
  }

  static bool get hasServiceWorker {
    if (!kIsWeb) return false;
    try { return js.context.hasProperty('navigator') && js.context['navigator'].hasProperty('serviceWorker'); } catch (_) { return false; }
  }

  static bool get hasPushManager {
    if (!kIsWeb) return false;
    try { return js.context.hasProperty('PushManager'); } catch (_) { return false; }
  }

  /// True when it's reasonable to initialize web push (skip on iOS Safari tabs)
  static bool get isWebPushSupported {
    if (!kIsWeb) return true;
    final supported = hasNotificationApi && hasServiceWorker && hasPushManager;
    if (isIOSWeb) {
      return supported && isStandalonePWA;
    }
    return supported;
  }
}


