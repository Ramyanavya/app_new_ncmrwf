// lib/services/location_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  // ─── GET CURRENT GPS POSITION ─────────────────────────────────────────────
  // Returns {lat, lon, name} or null on failure.
  // Handles permission requests automatically.
  Future<Map<String, dynamic>?> getCurrentPosition() async {
    try {
      // 1. Check if location services are enabled on the device
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[LocationService] ❌ Location services disabled on device');
        return null;
      }

      // 2. Check / request permission
      LocationPermission permission = await Geolocator.checkPermission();
      debugPrint('[LocationService] Current permission: $permission');

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        debugPrint('[LocationService] After request: $permission');
        if (permission == LocationPermission.denied) {
          debugPrint('[LocationService] ❌ Permission denied by user');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('[LocationService] ❌ Permission permanently denied');
        return null;
      }

      // 3. Get actual device coordinates
      // First try getLastKnownPosition for speed, but only if it's fresh (< 5 min)
      Position? pos;
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          final age = DateTime.now().difference(last.timestamp);
          if (age.inMinutes < 5) {
            pos = last;
            debugPrint('[LocationService] ✅ Using last known position (${age.inSeconds}s old): ${last.latitude}, ${last.longitude}');
          }
        }
      } catch (_) {}

      // Fall back to fresh GPS fix
      pos ??= await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 20),
      );

      final lat = pos.latitude;
      final lon = pos.longitude;
      debugPrint('[LocationService] ✅ GPS fix: $lat, $lon');

      // 4. Reverse-geocode to get a human-readable place name
      final placeName = await _reverseGeocode(lat, lon);
      debugPrint('[LocationService] ✅ Place name: $placeName');

      return {
        'lat':  lat,
        'lon':  lon,
        'name': placeName ?? 'Current Location',
      };
    } catch (e) {
      debugPrint('[LocationService] ❌ Error: $e');
      return null;
    }
  }

  // ─── OPEN APP SETTINGS ────────────────────────────────────────────────────
  // Call this when permission is permanently denied so user can enable manually
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  // ─── REVERSE GEOCODE ──────────────────────────────────────────────────────
  Future<String?> _reverseGeocode(double lat, double lon) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
            '?lat=$lat&lon=$lon&format=json&accept-language=en',
      );
      final res = await http.get(url, headers: {
        'User-Agent':      'NCMRWFWeatherApp/1.0',
        'Accept-Language': 'en',
      }).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data    = json.decode(res.body) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>? ?? {};

        final name =
            address['city']           ??
                address['town']           ??
                address['village']        ??
                address['suburb']         ??
                address['county']         ??
                address['state_district'] ??
                address['state'];

        final state = address['state'] as String?;

        if (name != null && state != null && name != state) {
          return '$name, $state';
        }
        if (name != null) return name as String;

        final display = data['display_name'] as String?;
        if (display != null) return display.split(',').first.trim();
      }
    } catch (e) {
      debugPrint('[LocationService] Reverse geocode failed: $e');
    }
    return null;
  }

  // ─── SEARCH PLACES ────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> searchPlaces(
      String query, {
        String langCode = 'en',
      }) async {
    if (query.trim().length < 2) return [];

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
            '?q=${Uri.encodeComponent(query)}'
            '&format=json'
            '&limit=10'
            '&countrycodes=in'
            '&accept-language=$langCode',
      );

      final res = await http.get(url, headers: {
        'User-Agent':      'NCMRWFWeatherApp/1.0',
        'Accept-Language': langCode,
      }).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final List data = json.decode(res.body);
        return data.map((e) {
          final parts       = (e['display_name'] as String).split(',');
          final displayName = parts.take(3).join(', ').trim();
          final shortName   = parts.first.trim();
          return {
            'name':     displayName,
            'short':    shortName,
            'fullName': e['display_name'] as String,
            'lat':      double.parse(e['lat']),
            'lon':      double.parse(e['lon']),
          };
        }).toList();
      }
    } catch (_) {}
    return [];
  }
}