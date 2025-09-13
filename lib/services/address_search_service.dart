import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/here_config.dart';
import 'package:geocoding/geocoding.dart';

class AddressSearchService {
  static Future<List<Placemark>> search(String query, {double? lat, double? lng}) async {
    // TODO: Plug into HERE autocomplete or geocoding with proper API.
    return [];
  }
}