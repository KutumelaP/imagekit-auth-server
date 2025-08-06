import 'package:flutter/material.dart';
import '../services/security_service.dart';
import '../theme/app_theme.dart';

/// Production-ready input field with built-in security validation
/// Designed to be crash-safe and performance-friendly
class ProductionInputField extends StatefulWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool isPassword;
  final bool isRequired;
  final int? maxLength;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool enabled;
  final int? maxLines;
  final bool autofocus;

  const ProductionInputField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.keyboardType,
    this.isPassword = false,
    this.isRequired = false,
    this.maxLength,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.prefixIcon,
    this.suffixIcon,
    this.enabled = true,
    this.maxLines = 1,
    this.autofocus = false,
  });

  @override
  State<ProductionInputField> createState() => _ProductionInputFieldState();
}

class _ProductionInputFieldState extends State<ProductionInputField> {
  bool _obscureText = true;
  String? _errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: widget.controller,
          keyboardType: widget.keyboardType,
          obscureText: widget.isPassword && _obscureText,
          enabled: widget.enabled,
          maxLength: widget.maxLength,
          maxLines: widget.maxLines,
          autofocus: widget.autofocus,
          decoration: InputDecoration(
            labelText: widget.label + (widget.isRequired ? ' *' : ''),
            hintText: widget.hint,
            prefixIcon: widget.prefixIcon,
            suffixIcon: _buildSuffixIcon(),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.cloud),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.cloud),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.deepTeal, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.primaryRed),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.primaryRed, width: 2),
            ),
            filled: true,
            fillColor: widget.enabled ? AppTheme.angel : AppTheme.cloud.withOpacity(0.3),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            errorText: _errorText,
          ),
          onChanged: (value) {
            _validateInput(value);
            widget.onChanged?.call(value);
          },
          onFieldSubmitted: widget.onSubmitted,
          validator: (value) {
            return _validateInput(value);
          },
        ),
        if (_errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 12),
            child: Text(
              _errorText!,
              style: TextStyle(
                color: AppTheme.primaryRed,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget? _buildSuffixIcon() {
    if (widget.isPassword) {
      return IconButton(
        icon: Icon(
          _obscureText ? Icons.visibility : Icons.visibility_off,
          color: AppTheme.cloud,
        ),
        onPressed: () {
          setState(() {
            _obscureText = !_obscureText;
          });
        },
      );
    }
    return widget.suffixIcon;
  }

  String? _validateInput(String? value) {
    // Clear previous error
    setState(() {
      _errorText = null;
    });

    // Required field validation
    if (widget.isRequired && (value == null || value.trim().isEmpty)) {
      setState(() {
        _errorText = '${widget.label} is required';
      });
      return _errorText;
    }

    // Skip validation if empty and not required
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    // Sanitize input
    String? sanitizedValue = SecurityService.sanitizeInput(value);
    if (sanitizedValue == null) {
      setState(() {
        _errorText = 'Invalid characters detected';
      });
      return _errorText;
    }

    // Type-specific validation
    String? validationError = _validateByType(sanitizedValue);
    if (validationError != null) {
      setState(() {
        _errorText = validationError;
      });
      return _errorText;
    }

    // Custom validator
    if (widget.validator != null) {
      String? customError = widget.validator!(sanitizedValue);
      if (customError != null) {
        setState(() {
          _errorText = customError;
        });
        return _errorText;
      }
    }

    return null;
  }

  String? _validateByType(String value) {
    final keyboardType = widget.keyboardType;
    
    if (keyboardType == TextInputType.emailAddress) {
      if (!SecurityService.isValidEmail(value)) {
        return 'Please enter a valid email address';
      }
    } else if (keyboardType == TextInputType.phone) {
      if (!SecurityService.isValidPhone(value)) {
        return 'Please enter a valid phone number';
      }
    } else if (keyboardType == TextInputType.number || 
               keyboardType == const TextInputType.numberWithOptions(decimal: true)) {
      if (!SecurityService.isValidNumber(value)) {
        return 'Please enter a valid number';
      }
    } else {
      // Text validation
      if (value.length < 2) {
        return '${widget.label} must be at least 2 characters';
      }
      if (widget.maxLength != null && value.length > widget.maxLength!) {
        return '${widget.label} must be ${widget.maxLength} characters or less';
      }
    }
    return null;
  }
}

/// Production-ready email input field
class ProductionEmailField extends StatelessWidget {
  final TextEditingController? controller;
  final bool isRequired;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;

  const ProductionEmailField({
    super.key,
    this.controller,
    this.isRequired = false,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return ProductionInputField(
      label: 'Email',
      hint: 'Enter your email address',
      controller: controller,
      keyboardType: TextInputType.emailAddress,
      isRequired: isRequired,
      maxLength: 254,
      prefixIcon: Icon(Icons.email, color: AppTheme.cloud),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
  }
}

/// Production-ready password input field
class ProductionPasswordField extends StatelessWidget {
  final TextEditingController? controller;
  final bool isRequired;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;

  const ProductionPasswordField({
    super.key,
    this.controller,
    this.isRequired = false,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return ProductionInputField(
      label: 'Password',
      hint: 'Enter your password',
      controller: controller,
      keyboardType: TextInputType.visiblePassword,
      isPassword: true,
      isRequired: isRequired,
      maxLength: 128,
      prefixIcon: Icon(Icons.lock, color: AppTheme.cloud),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      validator: (value) {
        if (value != null && !SecurityService.isValidPassword(value)) {
          return 'Password must be at least 6 characters with letters and numbers';
        }
        return null;
      },
    );
  }
}

/// Production-ready phone input field
class ProductionPhoneField extends StatelessWidget {
  final TextEditingController? controller;
  final bool isRequired;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;

  const ProductionPhoneField({
    super.key,
    this.controller,
    this.isRequired = false,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return ProductionInputField(
      label: 'Phone Number',
      hint: 'Enter your phone number',
      controller: controller,
      keyboardType: TextInputType.phone,
      isRequired: isRequired,
      maxLength: 15,
      prefixIcon: Icon(Icons.phone, color: AppTheme.cloud),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
  }
}

/// Production-ready price input field
class ProductionPriceField extends StatelessWidget {
  final TextEditingController? controller;
  final bool isRequired;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;

  const ProductionPriceField({
    super.key,
    this.controller,
    this.isRequired = false,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return ProductionInputField(
      label: 'Price',
      hint: 'Enter price (e.g., 99.99)',
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      isRequired: isRequired,
      maxLength: 10,
      prefixIcon: Icon(Icons.receipt, color: AppTheme.cloud),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      validator: (value) {
        if (value != null && !SecurityService.isValidPrice(value)) {
          return 'Please enter a valid price between R0.01 and R999,999.99';
        }
        return null;
      },
    );
  }
} 