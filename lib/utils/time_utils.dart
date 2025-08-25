import 'package:flutter/material.dart';

class TimeUtils {
  /// Converts a time string in HH:MM format to AM/PM format
  /// Example: "14:30" -> "2:30 PM", "08:00" -> "8:00 AM"
  static String formatTimeToAmPm(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length != 2) return timeStr;
      
      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = int.tryParse(parts[1]) ?? 0;
      
      final timeOfDay = TimeOfDay(hour: hour, minute: minute);
      return formatTimeOfDayToAmPm(timeOfDay);
    } catch (e) {
      return timeStr; // Return original if parsing fails
    }
  }
  
  /// Converts TimeOfDay to AM/PM format
  /// Example: TimeOfDay(hour: 14, minute: 30) -> "2:30 PM"
  static String formatTimeOfDayToAmPm(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
  
  /// Converts time range to AM/PM format
  /// Example: "08:00 - 18:00" -> "8:00 AM - 6:00 PM"
  static String formatTimeRangeToAmPm(String openTime, String closeTime) {
    final openAmPm = formatTimeToAmPm(openTime);
    final closeAmPm = formatTimeToAmPm(closeTime);
    return '$openAmPm - $closeAmPm';
  }
}

