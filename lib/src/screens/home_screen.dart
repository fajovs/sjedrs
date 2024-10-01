
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sjedrsmobile/src/services/auth_service.dart';
import 'package:geolocator/geolocator.dart' as geolocator;
import 'package:permission_handler/permission_handler.dart';

class HomeScreen extends StatelessWidget {
  final AuthService _authService = AuthService();

  HomeScreen({super.key});

  void _logout(BuildContext context) async {
    try {
      await _authService.signOut();
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed: ${e.toString()}')),
      );
    }
  }

  void _request(BuildContext context) async {
    await _authService.createRequest();
    Navigator.pushReplacementNamed(context, '/user_waiting');
  }

  Future<void> _checkAndRedirect(BuildContext context) async {
    try {
      final hasAccept = await _authService.hasAccepted();
      final hasRequest = await _authService.hasRequestForCurrentUser();

      if (hasAccept) {
        Navigator.pushReplacementNamed(context, '/user_map');
      }

      if (hasRequest) {
        Navigator.pushReplacementNamed(context, '/user_waiting');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to check request status: ${e.toString()}')),
      );
    }
  }

  Future<bool> _onWillPop() async {
    return Future.value(false);
  }

  Future<void> _checkLocationServiceAndPermission(BuildContext context) async {
    bool serviceEnabled = await geolocator.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showLocationServiceAlert(context);

    }

    var permission = await Permission.location.request();
    if (permission.isGranted) {
      // Permission granted, proceed
    } else {
      _showPermissionDeniedAlert(context);
    }
  }

  void _showLocationServiceAlert(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Location Services Disabled"),
          content: const Text("Please enable location services to use this feature."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await openAppSettings();
              },
              child: const Text("Settings"),
            ),
          ],
        );
      },
    );
  }

  void _showPermissionDeniedAlert(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Permission Denied"),
          content: const Text("Location permission is required to use this feature."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<User?>(
      future: _authService.getCurrentUser() != null ? Future.value(_authService.getCurrentUser()) : null,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacementNamed(context, '/login');
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Check for location permission when the user is authenticated
        _checkLocationServiceAndPermission(context);
        _checkAndRedirect(context);

        return WillPopScope(
          onWillPop: _onWillPop,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Home'),
              backgroundColor: Colors.redAccent,
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () => _logout(context),
                  color: Colors.white,
                ),
              ],
            ),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Center(
                      child: Text(
                        'Welcome to ALISTO',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () => _request(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                      ),
                      child: const Text(
                        'Emergency Request',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // ElevatedButton(
                    //   onPressed: () => Navigator.pushReplacementNamed(context, '/map'),
                    //   style: ElevatedButton.styleFrom(
                    //     backgroundColor: Colors.redAccent,
                    //     minimumSize: const Size(double.infinity, 48),
                    //     shape: RoundedRectangleBorder(
                    //       borderRadius: BorderRadius.circular(12.0),
                    //     ),
                    //   ),
                    //   child: const Text(
                    //     'Map',
                    //     style: TextStyle(color: Colors.white),
                    //   ),
                    // ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
