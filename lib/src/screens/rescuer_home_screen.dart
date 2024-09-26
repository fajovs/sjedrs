import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sjedrsmobile/src/services/auth_service.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart' as geolocator;
import 'package:permission_handler/permission_handler.dart';

class RescuerHomeScreen extends StatefulWidget {
  const RescuerHomeScreen({super.key});

  @override
  _RescuerHomeScreenState createState() => _RescuerHomeScreenState();
}

class _RescuerHomeScreenState extends State<RescuerHomeScreen> {
  final AuthService _authService = AuthService();
  late final StreamSubscription _respondStreamSubscription;

  @override
  void initState() {
    super.initState();
    _checkAndRedirect();
    _checkLocationServiceAndPermission();
  }

  @override
  void dispose() {
    _respondStreamSubscription.cancel();
    super.dispose();
  }

  void _logout(BuildContext context) async {
    try {
      await _authService.signOut();
      Navigator.pushReplacementNamed(context, '/rescuer_login');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed: ${e.toString()}')),
      );
    }
  }

  Future<bool> _onWillPop() async {
    return Future.value(false);
  }

  String _formatTimestamp(String timestamp) {
    final dateTime = DateTime.parse(timestamp);
    final dateFormat = DateFormat('yyyy-MM-dd');
    final timeFormat = DateFormat('HH:mm:ss');
    return '${dateFormat.format(dateTime)} at ${timeFormat.format(dateTime)}';
  }

  void _handleRequestTap(String requestId, Map<String, dynamic> requestData) async {
    try {
      await _authService.saveToActiveAndDeleteRequest(requestId, requestData);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request processed and deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to process request: ${e.toString()}')),
      );
    }
  }

  void _checkAndRedirect() {
    _respondStreamSubscription = _authService.respondStream.listen(
          (requestsData) {
        final User? currentUser = _authService.getCurrentUser();
        if (currentUser == null) {
          Navigator.of(context).pushReplacementNamed('/rescuer_login');
          return;
        }

        Map<String, dynamic> requestsMap = requestsData is Map
            ? Map<String, dynamic>.from(requestsData as Map)
            : {};

        final hasAccepted = requestsMap.values.any(
              (request) => (request['ResponderUserID'] as String?) == currentUser.uid,
        );

        if (hasAccepted) {
          Navigator.of(context).pushReplacementNamed('/rescuer_map');
        }
      },
      onError: (error) {
        print('Error listening to request stream: $error');
      },
    );
  }

  Future<void> _checkLocationServiceAndPermission() async {
    bool serviceEnabled = await geolocator.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showLocationServiceAlert();
      return;
    }

    var permission = await Permission.location.request();
    if (!permission.isGranted) {
      _showPermissionDeniedAlert();
    }
  }

  void _showLocationServiceAlert() {
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

  void _showPermissionDeniedAlert() {
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
    return StreamBuilder<Map<dynamic, dynamic>>(
      stream: _authService.requestStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        final requestsData = snapshot.data ?? {};

        return WillPopScope(
          onWillPop: _onWillPop,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Rescuer Home'),
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
                    const Text(
                      'Request List',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Expanded(
                      child: ListView.builder(
                        itemCount: requestsData.length,
                        itemBuilder: (context, index) {
                          final requestId = requestsData.keys.elementAt(index);
                          final request = requestsData.values.elementAt(index);
                          final timestamp = request['timestamp'] as String;
                          final formattedTimestamp = _formatTimestamp(timestamp);
                          final userData = request['userData'] as Map<dynamic, dynamic>;

                          return Card(
                            elevation: 5,
                            margin: const EdgeInsets.symmetric(vertical: 8.0),
                            child: ListTile(
                              leading: const Icon(
                                Icons.warning,
                                color: Colors.redAccent,
                              ),
                              title: Text('Request from ${userData['name']}'),
                              subtitle: Text(
                                'Email: ${userData['email']}\nPhone: ${userData['phone']}\nTime: $formattedTimestamp',
                              ),
                              trailing: const Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.grey,
                              ),
                              onTap: () {
                                _handleRequestTap(requestId, request);
                              },
                            ),
                          );
                        },
                      ),
                    ),
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
