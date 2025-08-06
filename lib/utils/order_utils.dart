import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OrderUtils {
  /// Converts a technical order number to a human-readable format
  /// 
  /// Input format: ORD-DDMMYYYY-HHMM-XXX
  /// Output format: #ORD-DD/MM/YYYY-HH:MM-XXX
  /// 
  /// Example: ORD-28072025-1430-ABC -> #ORD-28/07/2025-14:30-ABC
  static String formatOrderNumber(String orderNumber) {
    if (orderNumber.isEmpty) return 'Unknown';
    
    // Handle cases where it's already formatted or doesn't match expected pattern
    if (orderNumber.startsWith('#')) return orderNumber;
    
    try {
      // Parse the technical format: ORD-DDMMYYYY-HHMM-XXX
      final parts = orderNumber.split('-');
      if (parts.length != 4 || parts[0] != 'ORD') {
        return '#$orderNumber'; // Return as-is with # prefix
      }
      
      final datePart = parts[1]; // DDMMYYYY
      final timePart = parts[2]; // HHMM
      final userPart = parts[3]; // XXX
      
      if (datePart.length != 8 || timePart.length != 4) {
        return '#$orderNumber'; // Return as-is with # prefix
      }
      
      final day = datePart.substring(0, 2);
      final month = datePart.substring(2, 4);
      final year = datePart.substring(4, 8);
      final hour = timePart.substring(0, 2);
      final minute = timePart.substring(2, 4);
      
      return '#ORD-$day/$month/$year-$hour:$minute-$userPart';
    } catch (e) {
      return '#$orderNumber'; // Return as-is with # prefix
    }
  }
  
  /// Converts a technical order number to a short human-readable format
  /// 
  /// Input format: ORD-DDMMYYYY-HHMM-XXX
  /// Output format: #ORD-DD/MM-HH:MM-XXX
  /// 
  /// Example: ORD-28072025-1430-ABC -> #ORD-28/07-14:30-ABC
  static String formatShortOrderNumber(String orderNumber) {
    if (orderNumber.isEmpty) return 'Unknown';
    
    // Handle cases where it's already formatted or doesn't match expected pattern
    if (orderNumber.startsWith('#')) return orderNumber;
    
    try {
      // Parse the technical format: ORD-DDMMYYYY-HHMM-XXX
      final parts = orderNumber.split('-');
      if (parts.length != 4 || parts[0] != 'ORD') {
        return '#$orderNumber'; // Return as-is with # prefix
      }
      
      final datePart = parts[1]; // DDMMYYYY
      final timePart = parts[2]; // HHMM
      final userPart = parts[3]; // XXX
      
      if (datePart.length != 8 || timePart.length != 4) {
        return '#$orderNumber'; // Return as-is with # prefix
      }
      
      final day = datePart.substring(0, 2);
      final month = datePart.substring(2, 4);
      final hour = timePart.substring(0, 2);
      final minute = timePart.substring(2, 4);
      
      return '#ORD-$day/$month-$hour:$minute-$userPart';
    } catch (e) {
      return '#$orderNumber'; // Return as-is with # prefix
    }
  }
  
  /// Converts a technical order number to a very short format for mobile displays
  /// 
  /// Input format: ORD-DDMMYYYY-HHMM-XXX
  /// Output format: #ORD-DD/MM-XXX
  /// 
  /// Example: ORD-28072025-1430-ABC -> #ORD-28/07-ABC
  static String formatVeryShortOrderNumber(String orderNumber) {
    if (orderNumber.isEmpty) return 'Unknown';
    
    // Handle cases where it's already formatted or doesn't match expected pattern
    if (orderNumber.startsWith('#')) return orderNumber;
    
    try {
      // Parse the technical format: ORD-DDMMYYYY-HHMM-XXX
      final parts = orderNumber.split('-');
      if (parts.length != 4 || parts[0] != 'ORD') {
        return '#$orderNumber'; // Return as-is with # prefix
      }
      
      final datePart = parts[1]; // DDMMYYYY
      final userPart = parts[3]; // XXX
      
      if (datePart.length != 8) {
        return '#$orderNumber'; // Return as-is with # prefix
      }
      
      final day = datePart.substring(0, 2);
      final month = datePart.substring(2, 4);
      
      return '#ORD-$day/$month-$userPart';
    } catch (e) {
      return '#$orderNumber'; // Return as-is with # prefix
    }
  }

  /// Formats a timestamp to a readable date string
  static String formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    
    try {
      DateTime dateTime;
      
      if (timestamp is Timestamp) {
        dateTime = timestamp.toDate();
      } else if (timestamp is DateTime) {
        dateTime = timestamp;
      } else if (timestamp is String) {
        dateTime = DateTime.parse(timestamp);
      } else {
        return 'Unknown';
      }
      
      return DateFormat('MMM dd, yyyy HH:mm').format(dateTime);
    } catch (e) {
      return 'Unknown';
    }
  }
  
  /// Gets a friendly order date from the order number
  /// 
  /// Input format: ORD-DDMMYYYY-HHMM-XXX
  /// Output format: "28 July 2025 at 2:30 PM"
  static String getOrderDate(String orderNumber) {
    if (orderNumber.isEmpty) return 'Unknown Date';
    
    try {
      // Parse the technical format: ORD-DDMMYYYY-HHMM-XXX
      final parts = orderNumber.split('-');
      if (parts.length != 4 || parts[0] != 'ORD') {
        return 'Unknown Date';
      }
      
      final datePart = parts[1]; // DDMMYYYY
      final timePart = parts[2]; // HHMM
      
      if (datePart.length != 8 || timePart.length != 4) {
        return 'Unknown Date';
      }
      
      final day = int.parse(datePart.substring(0, 2));
      final month = int.parse(datePart.substring(2, 4));
      final year = int.parse(datePart.substring(4, 8));
      final hour = int.parse(timePart.substring(0, 2));
      final minute = int.parse(timePart.substring(2, 4));
      
      final date = DateTime(year, month, day, hour, minute);
      final formatter = DateFormat('d MMMM yyyy \'at\' h:mm a');
      return formatter.format(date);
    } catch (e) {
      return 'Unknown Date';
    }
  }
} 