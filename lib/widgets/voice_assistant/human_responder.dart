import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../services/product_store_lookup_service.dart';

class HumanResponder {
  static final HumanResponder _instance = HumanResponder._internal();
  factory HumanResponder() => _instance;
  HumanResponder._internal();

  // Playful mini knowledge base for quick, human-like replies
  static const Map<String, List<String>> _playfulKb = {
    "greetings": [
      "Hey there! Nathan here. Ready to help you shop!",
      "Hi! Let’s find something awesome together.",
      "Hello! Your shopping buddy Nathan here.",
    ],
    "orders": [
      "To cancel an order, tap the cancel button in 'My Orders'.",
      "Track your orders in 'My Orders'—you'll see updates in real time.",
      "Changed your mind? Go to 'My Orders' and tap cancel.",
    ],
    "payments": [
      "We accept credit cards, SnapScan, and PayPal.",
      "Refunds take 3–5 business days.",
      "Payment is flexible: cards, mobile payments, or cash on delivery.",
    ],
    "shipping": [
      "Standard shipping: 3–5 days. Express shipping depends on availability.",
      "We deliver to your door or pickup points, with tracking included.",
    ],
    "small_talk": [
      "I love helping people find good stuff. What are you shopping for today?",
      "Tip: Following sellers helps you catch deals faster.",
      "I’m always learning. Tell me what you need and I’ll help.",
    ],
  };


  String humanize(String input, {String? context}) {
    final normalized = input.trim();
    // Trim long lines and add friendly tone
    String out = normalized;
    out = out.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (out.length > 180) {
      out = out.substring(0, 175).trimRight() + '...';
    }
    out = _soften(out);
    _debug('humanize => "${_short(out)}" (context="${context ?? ''}")');
    return out;
  }

  Future<String?> generateHelpfulAnswerAsync(String userQuestion, {String? context}) async {
    final q = userQuestion.toLowerCase();
    _debug('helpfulAsync IN => "${_short(userQuestion)}" (ctx="${context ?? ''}")');

    // 1) Direct: "which stores do you have?" (no category)
    if (RegExp(r'\b(which|what)\b.*\bstores?\b.*\bdo you have\b').hasMatch(q) ||
        RegExp(r'\bwhat stores are (available|there)\b').hasMatch(q)) {
      _debug('intent => list stores (generic)');
      final names = await ProductStoreLookupService.listStoreNames(maxStores: 5);
      if (names.isNotEmpty) {
        final list = names.join(', ');
        return _format(
          lead: 'Here are a few stores we have',
          steps: [list],
        );
      }
      return 'I couldn’t find store names right now.';
    }

    // 2) Category-aware: "which food stores do you have?" => use detected category word
    if (RegExp(r'\b(which|what)\b.*\b([a-z]+)\b.*\bstores?\b.*\bdo you have\b').hasMatch(q)) {
      final match = RegExp(r'\b(which|what)\b.*\b([a-z]+)\b.*\bstores?\b.*\bdo you have\b').firstMatch(q);
      final rawCategory = match?.group(2);
      if (rawCategory != null && rawCategory.isNotEmpty) {
        final category = _normalizeCategory(rawCategory);
        _debug('intent => list stores (category="$category")');
        final names = await ProductStoreLookupService.listStoreNames(category: category, maxStores: 5);
        if (names.isNotEmpty) {
          final list = names.join(', ');
          return _format(
            lead: 'Here are a few $category stores',
            steps: [list],
          );
        }
        return 'I couldn’t find $category stores right now.';
      }
    }

    // 3) Navigation capability: "can you take me to ..."
    if (q.contains('take me to') || q.contains('navigate to') || q.contains('open') && q.contains('store')) {
      _debug('intent => navigation not supported');
      return _format(
        lead: 'I can’t open pages for you yet',
        steps: [
          'I can show where to find things and which stores have them',
          'Soon I’ll be able to take you directly there',
        ],
      );
    }

    // 4) Trust/safety questions: "can I trust this app?"
    if (q.contains('can i trust') || q.contains('is this app safe') || q.contains('is this safe')) {
      _debug('intent => trust/safety');
      return _format(
        lead: 'Yes—you’re in control and your data is protected',
        steps: [
          'Payments go through secure, industry-standard providers',
          'Sellers are verified, and you can see ratings and reviews',
        ],
      );
    }

    // Pricing/billing style question (avoid product lookup on generic words like "month")
    if ((q.contains('how much') || q.contains('howmuch')) &&
        (q.contains('month') || q.contains('monthly') || q.contains('per month') || q.contains('pay'))) {
      _debug('intent => pricing/monthly');
      return _format(
        lead: 'Pricing depends on what you add to your cart',
        steps: [
          "You'll see the total at checkout.",
          "Want me to open Search to get started?",
        ],
      );
    }

    // Product/store search intent
    if (_hasAny(q, ['store', 'shop', 'sell', 'have', 'stock', 'buy', 'where', 'find', 'want', 'need', 'looking', 'search'])) {
      final keyword = _normalizeKeyword(_extractKeyword(q));
      _debug('detected product/store intent; keyword="$keyword"');
      if (keyword != null && keyword.length >= 3 && !_isGeneric(keyword)) {
        // Try real lookup; if nothing, acknowledge clearly
        final real = await ProductStoreLookupService.suggestStoresForQuery(userQuestion);
        if (real != null && real.trim().isNotEmpty) {
          _debug('store lookup SUCCESS => "${_short(real)}"');
          return real;
        }
        _debug('store lookup EMPTY for "$keyword"');
        return _format(
          lead: "I couldn’t find any stores for that right now",
          steps: [
            "Try a slightly different name or check another category.",
          ],
        );
      }
      // Ask a targeted clarifier instead of generic FAQ tone
      final clarifier = _buildClarifier(q);
      if (clarifier != null) {
        _debug('clarifier => "${_short(clarifier)}"');
        return clarifier;
      }
      return _format(
        lead: "Want me to search it?",
        steps: [
          "Say a keyword like 'cake' and I’ll show nearby stores.",
          "You can also tell me a category—Food, Electronics, or Clothing.",
        ],
      );
    }

    // How-to checkout / orders / delivery / payment
    if (_hasAll(q, ['how', 'order']) || _hasAll(q, ['place', 'order'])) {
      _debug('intent => orders/how-to');
      return _format(
        lead: "Placing an order is quick:",
        steps: [
          "Add items to your cart, then tap Checkout.",
          "Choose delivery or pickup and your payment method.",
          "Confirm—your order will appear in Orders with live updates.",
        ],
      );
    }
    if (_hasAll(q, ['track', 'order']) || _hasAll(q, ['where', 'order'])) {
      _debug('intent => track/order');
      return _format(
        lead: "Here’s how to track it:",
        steps: [
          "Open Orders and select your order.",
          "You’ll see the current status and delivery progress.",
        ],
      );
    }
    if (_hasAny(q, ['delivery', 'deliver'])) {
      _debug('intent => delivery');
      return _format(
        lead: "Delivery is flexible:",
        steps: [
          "Choose delivery or pickup at checkout.",
          "We’ll show options and ETA for your area.",
        ],
      );
    }
    if (_hasAny(q, ['payment', 'pay', 'card', 'cash'])) {
      _debug('intent => payment');
      return _format(
        lead: "Payment methods supported:",
        steps: [
          "Card, mobile payments, or cash on delivery (when available).",
          "Pick your preferred method at checkout—simple and secure.",
        ],
      );
    }

    // Polite, concise default
    _debug('no intent match; returning null');
    return null;
  }

  // Generate a playful, human-like reply based on simple intent matching
  String? generatePlayfulReply(String userQuestion) {
    final intent = _matchIntent(userQuestion);
    if (intent != 'greetings') return null;
    final options = _playfulKb[intent];
    if (options == null || options.isEmpty) return null;
    final reply = _playful(options);
    _debug('playful greeting => "${_short(reply)}"');
    return reply;
  }

  String _format({required String lead, required List<String> steps}) {
    // Conversational, not FAQ-ish. No bullets, 1–2 short fragments.
    final fragments = steps.where((e) => e.trim().isNotEmpty).toList();
    if (fragments.isEmpty) return lead.replaceAll(':', ' —');

    // Normalize lead
    String l = lead.trim();
    l = l.replaceAll(':', ' —');
    // Avoid awkward "—." combo
    final ltrim = l.trimRight();
    if (!ltrim.endsWith('—') && !ltrim.endsWith('.') && !ltrim.endsWith('!')) {
      l = '$l.';
    }

    final connectors = [
      ' then ',
      ' you can also ',
      ' or ',
      ' afterwards, ',
    ];

    // Pick up to 2 fragments to keep it light
    final first = fragments.first;
    final second = fragments.length > 1 ? fragments[1] : null;
    String sentence = '$l ${_trimPeriod(first)}';
    if (second != null) {
      final conn = connectors[Random().nextInt(connectors.length)];
      sentence += conn + _lcFirst(_trimPeriod(second));
    }
    if (!sentence.endsWith('.') && !sentence.endsWith('!')) sentence += '.';
    return sentence;
  }

  String _soften(String text) {
    // Replace robotic templates with friendly phrasing
    String t = text;
    t = t.replaceAll(RegExp(r"I understand you're asking about \\b", caseSensitive: false), '');
    t = t.replaceAll(RegExp(r"Could you be more specific[^.?!]*[.?!]?", caseSensitive: false),
        _pick([
          "What would you like to focus on—search, stores, or checkout?",
          "Want me to search for it or show stores?",
        ]));
    // Avoid repeating the user’s full question verbatim
    if (t.length < 12) {
      t = _pick([
        "Sure—tell me what you need and I’ll help.",
        "Happy to help—what are you looking for?",
      ]);
    }
    return t.trim();
  }

  String _trimPeriod(String s) {
    String out = s.trim();
    while (out.endsWith('.') || out.endsWith('!')) {
      out = out.substring(0, out.length - 1).trimRight();
    }
    return out;
  }

  String _lcFirst(String s) {
    if (s.isEmpty) return s;
    return s[0].toLowerCase() + s.substring(1);
  }

  String _composeProductSuggestion(String keyword) {
    // This is now unused since we removed the hardcoded catalog, but keep a helpful path if ever called.
    final lead = _pick(["Here’s how to spot it.", "Let’s get you there fast.", "You can find that quickly."]);
    final steps = [
      "Open Search and type \"$keyword\".",
      "Filter by price and rating, then open a store you like.",
    ];
    return _format(lead: lead, steps: steps);
  }

  bool _hasAny(String q, List<String> words) => words.any((w) => q.contains(w));
  bool _hasAll(String q, List<String> words) => words.every((w) => q.contains(w));

  String? _extractKeyword(String q) {
    // Heuristic: extract last meaningful noun-like token from question
    final tokens = q.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ').split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return null;
    // Prefer last token if meaningful; else fallback to any non-stopword
    final stop = {
      'do','you','have','any','that','to','for','a','the','and','or','with','on','of','is','are','there','this','how','where','what'
    };
    for (int i = tokens.length - 1; i >= 0; i--) {
      final t = tokens[i];
      if (t.length >= 3 && !stop.contains(t)) return t;
    }
    return null;
  }

  String _pick(List<String> options) => options[Random().nextInt(options.length)];

  // Intent matching and playful compose
  String _matchIntent(String input) {
    final lower = input.toLowerCase();
    bool containsWord(String text, String word) {
      final re = RegExp('\\b' + RegExp.escape(word) + '\\b');
      return re.hasMatch(text);
    }
    if (["hi", "hello", "hey", "good morning", "good afternoon", "good evening"]
        .any((w) => containsWord(lower, w))) return "greetings";
    if (["order", "cancel", "track"].any((w) => containsWord(lower, w))) return "orders";
    if (["pay", "payment", "refund"].any((w) => containsWord(lower, w))) return "payments";
    if (["ship", "delivery", "deliver"].any((w) => containsWord(lower, w))) return "shipping";
    return "small_talk";
  }

  String _playful(List<String> options) {
    // Keep it clean and neutral—no emojis or extra interjections
    return options[Random().nextInt(options.length)];
  }

  String? _buildClarifier(String q) {
    // Tailored clarifier to feel attentive
    if (_hasAny(q, ['store', 'shop'])) {
      return _pick([
        "Which item are you after—like cake, bread, or pizza? I’ll find stores near you.",
        "Tell me what you want to buy and I’ll pull up stores with prices.",
      ]);
    }
    if (_hasAny(q, ['find', 'buy', 'have', 'stock'])) {
      return _pick([
        "Say the item name—e.g., 'cake'—and I’ll show stores and price ranges.",
        "What’s the product name? I’ll search stores and show options.",
      ]);
    }
    return null;
  }

  String? _normalizeKeyword(String? k) {
    if (k == null) return null;
    final norm = k.trim();
    if (norm == 'store' || norm == 'shops' || norm == 'shop' || norm == 'buy' || norm == 'find') return null;
    return norm;
  }

  String _normalizeCategory(String category) {
    final normalized = category.toLowerCase().trim();
    
    // Map common category variations to standard categories
    switch (normalized) {
      case 'food':
      case 'foods':
      case 'grocery':
      case 'groceries':
        return 'food';
      case 'clothing':
      case 'clothes':
      case 'fashion':
        return 'clothing';
      case 'electronics':
      case 'electronic':
      case 'tech':
        return 'electronics';
      case 'beauty':
      case 'cosmetics':
      case 'makeup':
        return 'beauty';
      case 'home':
      case 'household':
      case 'furniture':
        return 'home';
      case 'sports':
      case 'fitness':
      case 'gym':
        return 'sports';
      case 'books':
      case 'book':
      case 'education':
        return 'books';
      case 'toys':
      case 'toy':
      case 'games':
        return 'toys';
      case 'health':
      case 'medical':
      case 'pharmacy':
        return 'health';
      default:
        return normalized;
    }
  }

  bool _isGeneric(String k) {
    const generic = {'store','shop','buy','find','sell','stock','have','product','item'};
    return generic.contains(k.toLowerCase());
  }

  void _debug(String msg) {
    if (kDebugMode) {
      print('🤖 HumanResponder: ' + msg);
    }
  }

  String _short(String s, {int max = 120}) {
    if (s.length <= max) return s;
    return s.substring(0, max - 3) + '...';
  }
}


