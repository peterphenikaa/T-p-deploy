import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:food_delivery_app/config/env.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'home_pages.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class PermissionPage extends StatefulWidget {
  @override
  _PermissionPageState createState() => _PermissionPageState();
}

class _PermissionPageState extends State<PermissionPage> {
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureLocation());
  }

  Future<void> _ensureLocation() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      var status = await Permission.location.status;
      if (status.isDenied) {
        status = await Permission.location.request();
      }

      if (status.isPermanentlyDenied) {
        setState(() {
          _error = 'Permission permanently denied. Please enable in settings.';
          _loading = false;
        });
        return;
      }

      if (!status.isGranted) {
        setState(() {
          _error = 'Location permission denied';
          _loading = false;
        });
        return;
      }

      if (!kIsWeb) {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          setState(() {
            _error = 'Location services are disabled. Please enable GPS.';
            _loading = false;
          });
          return;
        }
      }

      final Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Try to send position to backend /api/location (best-effort)
      try {
        final payload = jsonEncode({
          'userId': 'anonymous', // replace with real user id if available
          'lat': pos.latitude,
          'lng': pos.longitude,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });

        final uriLocal = Uri.parse('$API_BASE_URL/api/location');
        final uriEmu = Uri.parse('$API_BASE_URL/api/location');

        try {
          final r = await http
              .post(
                uriLocal,
                headers: {'Content-Type': 'application/json'},
                body: payload,
              )
              .timeout(Duration(seconds: 8));
          if (!(r.statusCode >= 200 && r.statusCode < 300)) {
            setState(() {
              _error =
                  'Could not send location to server (status ${r.statusCode})';
            });
          }
        } catch (_) {
          // try emulator host (Android emulator)
          try {
            final r2 = await http
                .post(
                  uriEmu,
                  headers: {'Content-Type': 'application/json'},
                  body: payload,
                )
                .timeout(Duration(seconds: 8));
            if (!(r2.statusCode >= 200 && r2.statusCode < 300)) {
              setState(() {
                _error =
                    'Could not send location to server (status ${r2.statusCode})';
              });
            }
          } catch (err2) {
            // neither host worked
            print('Failed to send location to backend: $err2');
            setState(() {
              _error = 'Could not send location to server';
            });
          }
        }
      } catch (err) {
        // Best-effort only: log and show message but don't block navigation
        print('Failed to send location: $err');
        setState(() {
          _error = 'Could not send location to server';
        });
      }

      setState(() {
        _loading = false;
      });

      final args = (ModalRoute.of(context)?.settings.arguments as Map?) ?? {};
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomePage(),
          settings: RouteSettings(arguments: args),
        ),
      );
    } catch (e) {
      final message = e.toString();
      final userMessage = message.contains('MissingPluginException')
          ? 'Location plugin not registered. Try a full rebuild (flutter clean && flutter run).'
          : 'Could not get location: $e';
      setState(() {
        _error = userMessage;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 240,
                height: 240,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'introduction_screen/map.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _ensureLocation,
                  icon: Icon(Icons.location_on, color: Colors.white),
                  label: Text(
                    _loading ? 'LOADING...' : 'ACCESS LOCATION',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFFF4E02),
                    minimumSize: Size(230, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 14),
              if (_error != null) ...[
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red),
                ),
              ] else ...[
                Text(
                  "DFOOD WILL ACCESS YOUR LOCATION ONLY WHILE USING THE APP",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
