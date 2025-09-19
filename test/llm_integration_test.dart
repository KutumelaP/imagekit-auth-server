import 'package:flutter_test/flutter_test.dart';
import '../lib/services/llm_service.dart';

void main() {
  group('LLM Integration Tests', () {
    testWidgets('LLM Service Initialization', (WidgetTester tester) async {
      final llmService = LlmService();
      
      print('🧪 Testing LLM Service Initialization...');
      await llmService.initialize();
      
      print('✅ LLM Available: ${llmService.isAvailable}');
      print('✅ LLM Provider: ${llmService.provider}');
      
      expect(llmService.isAvailable, true, reason: 'LLM Service should be available with valid API key');
      expect(llmService.provider.toString(), 'LlmProvider.openai', reason: 'Should use OpenAI provider');
    });
    
    testWidgets('LLM Answer Generation', (WidgetTester tester) async {
      final llmService = LlmService();
      await llmService.initialize();
      
      if (llmService.isAvailable) {
        print('🧪 Testing LLM Answer Generation...');
        
        final response = await llmService.generateAnswer(
          userQuestion: "Hello, can you help me with shopping?",
          contextHint: "testing LLM integration",
        );
        
        print('✅ LLM Response: $response');
        
        expect(response, isNotNull, reason: 'LLM should generate a response');
        expect(response!.isNotEmpty, true, reason: 'Response should not be empty');
      } else {
        print('❌ LLM Service not available, skipping generation test');
      }
    });
    
    testWidgets('LLM Answer Refinement', (WidgetTester tester) async {
      final llmService = LlmService();
      await llmService.initialize();
      
      if (llmService.isAvailable) {
        print('🧪 Testing LLM Answer Refinement...');
        
        final refinedResponse = await llmService.refineAnswer(
          userQuestion: "How do I find products?",
          baseAnswer: "You can search for products using the search bar.",
          contextHint: "shopping app",
        );
        
        print('✅ Refined Response: $refinedResponse');
        
        expect(refinedResponse, isNotNull, reason: 'LLM should refine the answer');
        expect(refinedResponse.isNotEmpty, true, reason: 'Refined response should not be empty');
      } else {
        print('❌ LLM Service not available, skipping refinement test');
      }
    });
  });
}
