import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_keys.dart';

enum LlmProvider {
  openai,
  gemini,
  none,
}

class LlmService {
  static final LlmService _instance = LlmService._internal();
  factory LlmService() => _instance;
  LlmService._internal();

  LlmProvider _provider = LlmProvider.none;
  String? _openAiKey;
  String? _geminiKey;
  String _openAiModel = 'gpt-4o-mini';
  String _geminiModel = 'gemini-1.5-flash-latest';

  bool get isAvailable => _provider != LlmProvider.none;
  LlmProvider get provider => _provider;

  Future<void> initialize({
    String? openAiKey,
    String? geminiKey,
    LlmProvider? preferred,
  }) async {
    try {
      _openAiKey = openAiKey ?? ApiKeys.openAiKey;
      _geminiKey = geminiKey ?? ApiKeys.geminiKey;

      if (preferred != null) {
        switch (preferred) {
          case LlmProvider.openai:
            _provider = (_openAiKey != null && _openAiKey!.isNotEmpty)
                ? LlmProvider.openai
                : (_geminiKey != null && _geminiKey!.isNotEmpty)
                    ? LlmProvider.gemini
                    : LlmProvider.none;
            break;
          case LlmProvider.gemini:
            _provider = (_geminiKey != null && _geminiKey!.isNotEmpty)
                ? LlmProvider.gemini
                : (_openAiKey != null && _openAiKey!.isNotEmpty)
                    ? LlmProvider.openai
                    : LlmProvider.none;
            break;
          case LlmProvider.none:
            _provider = LlmProvider.none;
            break;
        }
      } else {
        if (_openAiKey != null && _openAiKey!.isNotEmpty) {
          _provider = LlmProvider.openai;
        } else if (_geminiKey != null && _geminiKey!.isNotEmpty) {
          _provider = LlmProvider.gemini;
        } else {
          _provider = LlmProvider.none;
        }
      }

      if (kDebugMode) {
        print('✅ LlmService initialized: provider=$_provider');
      }
    } catch (e) {
      _provider = LlmProvider.none;
      if (kDebugMode) {
        print('❌ LlmService init error: $e');
      }
    }
  }

  Future<String> refineAnswer({
    required String userQuestion,
    required String baseAnswer,
    String? contextHint,
    List<String>? relevantKnowledge,
    int maxTokens = 240,
  }) async {
    if (!isAvailable) return baseAnswer;

    final systemInstruction = _buildSystemInstruction(contextHint, relevantKnowledge);
    try {
      switch (_provider) {
        case LlmProvider.openai:
          return await _refineWithOpenAi(
            systemInstruction: systemInstruction,
            userQuestion: userQuestion,
            baseAnswer: baseAnswer,
            maxTokens: maxTokens,
          );
        case LlmProvider.gemini:
          return await _refineWithGemini(
            systemInstruction: systemInstruction,
            userQuestion: userQuestion,
            baseAnswer: baseAnswer,
            maxTokens: maxTokens,
          );
        case LlmProvider.none:
          return baseAnswer;
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ LLM refine failed, using base answer: $e');
      }
      return baseAnswer;
    }
  }

  /// Generate a helpful answer directly from the LLM when no base answer exists
  Future<String?> generateAnswer({
    required String userQuestion,
    String? contextHint,
    List<String>? relevantKnowledge,
    int maxTokens = 200,
  }) async {
    if (!isAvailable) return null;
    final systemInstruction = _buildDirectSystemInstruction(contextHint, relevantKnowledge);
    try {
      switch (_provider) {
        case LlmProvider.openai:
          return await _generateWithOpenAi(
            systemInstruction: systemInstruction,
            userQuestion: userQuestion,
            maxTokens: maxTokens,
          );
        case LlmProvider.gemini:
          return await _generateWithGemini(
            systemInstruction: systemInstruction,
            userQuestion: userQuestion,
            maxTokens: maxTokens,
          );
        case LlmProvider.none:
          return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ LLM generate failed: $e');
      }
      return null;
    }
  }

  String _buildDirectSystemInstruction(String? contextHint, List<String>? relevantKnowledge) {
    final buffer = StringBuffer();
    buffer.writeln('You are Nathan, a helpful assistant for the OmniaSA shopping app.');
    
    // Add relevant knowledge context first
    if (relevantKnowledge != null && relevantKnowledge.isNotEmpty) {
      buffer.writeln('\nRelevant knowledge from our database:');
      for (int i = 0; i < relevantKnowledge.length && i < 3; i++) {
        buffer.writeln('- ${relevantKnowledge[i]}');
      }
      buffer.writeln('\nUse this knowledge to enhance your answer, but keep it natural and conversational.');
    }
    
    buffer.writeln('\nAnswer the user succinctly with concrete steps or options in the app.');
    buffer.writeln('If the user asks about stores or products, guide them to:');
    buffer.writeln('- Use Search (what to type), categories (e.g., Food > Bakery), or filters.');
    buffer.writeln('- Mention how to find stores that carry an item (open a store, view products).');
    buffer.writeln('Constraints: Max 2 short sentences (< 60 words). No hallucinated store names.');
    
    if (contextHint != null && contextHint.trim().isNotEmpty) {
      buffer.writeln('Screen Context: $contextHint');
    }
    
    return buffer.toString();
  }

  Future<String?> _generateWithOpenAi({
    required String systemInstruction,
    required String userQuestion,
    required int maxTokens,
  }) async {
    final startTime = DateTime.now();
    final uri = Uri.parse('https://api.openai.com/v1/chat/completions');
    final body = {
      'model': _openAiModel,
      'messages': [
        {'role': 'system', 'content': systemInstruction},
        {'role': 'user', 'content': userQuestion},
      ],
      'temperature': 0.3,
      'max_tokens': maxTokens,
    };
    
    if (kDebugMode) {
      print('🤖 ===== OPENAI REQUEST START =====');
      print('🤖 Model: $_openAiModel');
      print('🤖 User Question: $userQuestion');
      print('🤖 Max Tokens: $maxTokens');
      print('🤖 System Instruction: ${systemInstruction.substring(0, min(systemInstruction.length, 200))}...');
      print('🤖 Request Body: ${jsonEncode(body)}');
      print('🤖 Timestamp: ${startTime.toIso8601String()}');
    }
    
    final resp = await http
        .post(
          uri,
          headers: {
            'Authorization': 'Bearer ${_openAiKey!}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 8));
    
    final endTime = DateTime.now();
    final duration = endTime.difference(startTime).inMilliseconds;
    
    if (kDebugMode) {
      print('🤖 Response Status: ${resp.statusCode}');
      print('🤖 Response Time: ${duration}ms');
      print('🤖 Response Body: ${resp.body}');
    }
    
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final choices = data['choices'] as List<dynamic>?;
      final content = choices?.first['message']?['content'] as String?;
      if (content != null && content.trim().isNotEmpty) {
        if (kDebugMode) {
          print('🤖 Generated Content: ${content.substring(0, min(content.length, 200))}...');
          print('🤖 ===== OPENAI REQUEST END =====');
        }
        return content.trim();
      }
    }
    if (kDebugMode) {
      print('⚠️ OpenAI generate returned ${resp.statusCode}: ${resp.body}');
      print('🤖 ===== OPENAI REQUEST END =====');
    }
    return null;
  }

  Future<String?> _generateWithGemini({
    required String systemInstruction,
    required String userQuestion,
    required int maxTokens,
  }) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1/models/$_geminiModel:generateContent?key=${_geminiKey!}',
    );
    final prompt = 'System instructions: $systemInstruction\n\nUser: $userQuestion';
    final body = {
      'contents': [
        {
          'parts': [
            {'text': prompt},
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.3,
        'maxOutputTokens': maxTokens,
      }
    };
    final resp = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 8));
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final candidates = data['candidates'] as List<dynamic>?;
      if (candidates != null && candidates.isNotEmpty) {
        final content = candidates.first['content'];
        if (content != null && content['parts'] is List && content['parts'].isNotEmpty) {
          final text = content['parts'][0]['text'] as String?;
          if (text != null && text.trim().isNotEmpty) return text.trim();
        }
      }
    }
    if (kDebugMode) {
      print('⚠️ Gemini generate returned ${resp.statusCode}: ${resp.body}');
    }
    return null;
  }

  String _buildSystemInstruction(String? contextHint, List<String>? relevantKnowledge) {
    final buffer = StringBuffer();
    buffer.writeln('You are Nathan, a friendly shopping assistant for OmniaSA.');
    buffer.writeln('Rewrite the draft answer to be concise, clear, and helpful.');
    buffer.writeln('Constraints:');
    buffer.writeln('- Keep facts from the draft; do not invent new details.');
    buffer.writeln('- 1-2 sentences, under 75 words.');
    buffer.writeln('- South African English; warm, positive tone.');
    buffer.writeln('- If the user asked how-to, give direct, actionable steps.');
    buffer.writeln('- If appropriate, add a tiny tip at the end.');
    if (contextHint != null && contextHint.trim().isNotEmpty) {
      buffer.writeln('Context: $contextHint');
    }
    return buffer.toString();
  }

  Future<String> _refineWithOpenAi({
    required String systemInstruction,
    required String userQuestion,
    required String baseAnswer,
    required int maxTokens,
  }) async {
    final startTime = DateTime.now();
    final uri = Uri.parse('https://api.openai.com/v1/chat/completions');
    final body = {
      'model': _openAiModel,
      'messages': [
        {'role': 'system', 'content': systemInstruction},
        {
          'role': 'user',
          'content': 'User question: $userQuestion\nDraft answer: $baseAnswer'
        },
      ],
      'temperature': 0.3,
      'max_tokens': maxTokens,
    };

    if (kDebugMode) {
      print('🔧 ===== OPENAI REFINE REQUEST START =====');
      print('🔧 Model: $_openAiModel');
      print('🔧 User Question: $userQuestion');
      print('🔧 Base Answer: ${baseAnswer.substring(0, min(baseAnswer.length, 100))}...');
      print('🔧 Max Tokens: $maxTokens');
      print('🔧 System Instruction: ${systemInstruction.substring(0, min(systemInstruction.length, 200))}...');
      print('🔧 Timestamp: ${startTime.toIso8601String()}');
    }

    final resp = await http
        .post(
          uri,
          headers: {
            'Authorization': 'Bearer ${_openAiKey!}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 8));

    final endTime = DateTime.now();
    final duration = endTime.difference(startTime).inMilliseconds;

    if (kDebugMode) {
      print('🔧 Response Status: ${resp.statusCode}');
      print('🔧 Response Time: ${duration}ms');
    }

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final choices = data['choices'] as List<dynamic>?;
      if (choices != null && choices.isNotEmpty) {
        final content = choices.first['message']?['content'] as String?;
        if (content != null && content.trim().isNotEmpty) {
          if (kDebugMode) {
            print('🔧 Refined Content: ${content.substring(0, min(content.length, 200))}...');
            print('🔧 ===== OPENAI REFINE REQUEST END =====');
          }
          return content.trim();
        }
      }
    }
    if (kDebugMode) {
      print('⚠️ OpenAI refine returned status ${resp.statusCode}: ${resp.body}');
      print('🔧 ===== OPENAI REFINE REQUEST END =====');
    }
    return baseAnswer;
  }

  Future<String> _refineWithGemini({
    required String systemInstruction,
    required String userQuestion,
    required String baseAnswer,
    required int maxTokens,
  }) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1/models/$_geminiModel:generateContent?key=${_geminiKey!}',
    );

    final prompt = 'System instructions: $systemInstruction\n\nUser question: $userQuestion\nDraft answer: $baseAnswer';

    final body = {
      'contents': [
        {
          'parts': [
            {'text': prompt},
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.3,
        'maxOutputTokens': maxTokens,
      }
    };

    final resp = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 8));

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final candidates = data['candidates'] as List<dynamic>?;
      if (candidates != null && candidates.isNotEmpty) {
        final content = candidates.first['content'];
        if (content != null && content['parts'] is List && content['parts'].isNotEmpty) {
          final firstPart = content['parts'][0];
          final text = firstPart['text'] as String?;
          if (text != null && text.trim().isNotEmpty) return text.trim();
        }
      }
    }
    if (kDebugMode) {
      print('⚠️ Gemini refine returned status ${resp.statusCode}: ${resp.body}');
    }
    return baseAnswer;
  }
}


