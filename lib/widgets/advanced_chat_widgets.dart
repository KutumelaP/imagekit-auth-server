import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../services/ai_chat_assistant.dart';

// AI Suggestion Chips Widget
class AISuggestionChips extends StatelessWidget {
  final List<String> suggestions;
  final Function(String) onSuggestionTap;
  final bool isLoading;

  const AISuggestionChips({
    super.key,
    required this.suggestions,
    required this.onSuggestionTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                size: 16,
                color: AppTheme.deepTeal,
              ),
              const SizedBox(width: 8),
              Text(
                'AI Suggestions',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.deepTeal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions.map((suggestion) {
              return _buildSuggestionChip(suggestion, context);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String suggestion, BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : () => onSuggestionTap(suggestion),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.deepTeal.withOpacity(0.1),
              AppTheme.deepTeal.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.deepTeal.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lightbulb_outline,
              size: 14,
              color: AppTheme.deepTeal,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                suggestion,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.deepTeal,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Enhanced Message Bubble with Reactions
class EnhancedMessageBubble extends StatefulWidget {
  final Map<String, dynamic> message;
  final bool isFromMe;

  const EnhancedMessageBubble({
    super.key,
    required this.message,
    required this.isFromMe,
  });

  @override
  State<EnhancedMessageBubble> createState() => _EnhancedMessageBubbleState();
}

class _EnhancedMessageBubbleState extends State<EnhancedMessageBubble> {
  @override
  Widget build(BuildContext context) {
    final messageType = widget.message['messageType'] ?? 'text';
    final text = widget.message['text'] ?? '';
    final timestamp = widget.message['timestamp'] as Timestamp?;
    final timeString = timestamp != null 
        ? '${timestamp.toDate().hour.toString().padLeft(2, '0')}:${timestamp.toDate().minute.toString().padLeft(2, '0')}'
        : '';

    return Align(
      alignment: widget.isFromMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          left: widget.isFromMe ? 50 : 8,
          right: widget.isFromMe ? 8 : 50,
          bottom: 4,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: widget.isFromMe 
              ? AppTheme.deepTeal 
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Message Text
            Text(
              text,
              style: TextStyle(
                color: widget.isFromMe ? Colors.white : Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
            
            const SizedBox(height: 4),
            
            // Timestamp
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                timeString,
                style: TextStyle(
                  color: widget.isFromMe 
                      ? Colors.white.withOpacity(0.7) 
                      : Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}