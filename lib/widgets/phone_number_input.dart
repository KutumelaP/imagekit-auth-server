import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class PhoneNumberInput extends StatefulWidget {
  final String? initialPhone;
  final Function(String?) onPhoneChanged;
  final String? hintText;
  final bool isRequired;

  const PhoneNumberInput({
    Key? key,
    this.initialPhone,
    required this.onPhoneChanged,
    this.hintText = 'Enter phone number for delivery coordination',
    this.isRequired = true,
  }) : super(key: key);

  @override
  State<PhoneNumberInput> createState() => _PhoneNumberInputState();
}

class _PhoneNumberInputState extends State<PhoneNumberInput> {
  late TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialPhone);
    _controller.addListener(_validatePhone);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _validatePhone() {
    final phone = _controller.text.trim();
    String? error;

    if (widget.isRequired && phone.isEmpty) {
      error = 'Phone number is required for delivery coordination';
    } else if (phone.isNotEmpty && !_isValidSAPhoneNumber(phone)) {
      error = 'Please enter a valid South African phone number';
    }

    setState(() {
      _errorText = error;
    });

    // Only notify parent if phone is valid or empty (when not required)
    if (error == null || (!widget.isRequired && phone.isEmpty)) {
      widget.onPhoneChanged(_formatPhoneNumber(phone));
    } else {
      widget.onPhoneChanged(null);
    }
  }

  bool _isValidSAPhoneNumber(String phone) {
    // Remove all non-digit characters
    final cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    // Check South African phone number patterns
    // Mobile: +27 6x xxx xxxx, +27 7x xxx xxxx, +27 8x xxx xxxx
    // Landline: +27 1x xxx xxxx, +27 2x xxx xxxx, +27 3x xxx xxxx, +27 4x xxx xxxx
    if (cleaned.startsWith('27')) {
      return cleaned.length == 11 && 
             (cleaned.startsWith('276') || cleaned.startsWith('277') || 
              cleaned.startsWith('278') || cleaned.startsWith('271') ||
              cleaned.startsWith('272') || cleaned.startsWith('273') ||
              cleaned.startsWith('274'));
    } else if (cleaned.startsWith('0')) {
      return cleaned.length == 10 &&
             (cleaned.startsWith('06') || cleaned.startsWith('07') ||
              cleaned.startsWith('08') || cleaned.startsWith('01') ||
              cleaned.startsWith('02') || cleaned.startsWith('03') ||
              cleaned.startsWith('04'));
    }
    
    return false;
  }

  String _formatPhoneNumber(String phone) {
    if (phone.isEmpty) return '';
    
    final cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    // Convert to international format
    if (cleaned.startsWith('0') && cleaned.length == 10) {
      return '+27${cleaned.substring(1)}';
    } else if (cleaned.startsWith('27') && cleaned.length == 11) {
      return '+$cleaned';
    }
    
    return phone; // Return as-is if no standard format matches
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppTheme.cardGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardElevation,
        border: Border.all(
          color: AppTheme.breeze.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: AppTheme.lightGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppTheme.cloud.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.phone,
                  color: AppTheme.deepTeal,
                  size: 22,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Phone Number ${widget.isRequired ? "*" : ""}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        color: AppTheme.deepTeal,
                        letterSpacing: 0.2,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'For PUDO delivery coordination and notifications',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.mediumGrey,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          TextFormField(
            controller: _controller,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s\(\)]')),
            ],
            decoration: InputDecoration(
              hintText: widget.hintText,
              prefixText: '+27 ',
              prefixStyle: TextStyle(
                color: AppTheme.deepTeal,
                fontWeight: FontWeight.w600,
              ),
              hintStyle: TextStyle(
                color: AppTheme.mediumGrey.withOpacity(0.7),
                fontSize: 14,
              ),
              filled: true,
              fillColor: AppTheme.angel,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _errorText != null ? AppTheme.error : AppTheme.breeze.withOpacity(0.3),
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _errorText != null ? AppTheme.error : AppTheme.breeze.withOpacity(0.3),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _errorText != null ? AppTheme.error : AppTheme.deepTeal,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppTheme.error,
                  width: 2,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppTheme.error,
                  width: 2,
                ),
              ),
              errorText: _errorText,
              errorStyle: TextStyle(
                color: AppTheme.error,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            style: TextStyle(
              color: AppTheme.deepTeal,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (_controller.text.isNotEmpty && _errorText == null) ...[
            SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: AppTheme.success,
                  size: 16,
                ),
                SizedBox(width: 6),
                Text(
                  'Valid South African phone number',
                  style: TextStyle(
                    color: AppTheme.success,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
