import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:sjedrsmobile/src/services/auth_service.dart';

class UserWaitingScreen extends StatefulWidget {
  const UserWaitingScreen({super.key});

  @override
  State<UserWaitingScreen> createState() => _UserWaitingScreenState();
}

class _UserWaitingScreenState extends State<UserWaitingScreen> {
  final AuthService _authService = AuthService();
  bool _isProcessing = false; // Track if a request is being processed
  bool _hasRequest = false; // Track if the user has a request

  late final StreamSubscription _requestStreamSubscription; // To manage the stream

  @override
  void initState() {
    super.initState();

    _listenToRequestChanges();
  }




  void _listenToRequestChanges() {
    _requestStreamSubscription = _authService.requestStream.listen((requestsData) {
      final User? currentUser = _authService.getCurrentUser();

      if (currentUser == null) {
        // Handle the case where there is no logged-in user
        Navigator.of(context).pushReplacementNamed('/user_home');
        return;
      }

      final hasRequest = requestsData.values.any(
            (request) => (request['userId'] as String?) == currentUser.uid,
      );

      if (!hasRequest) {
        Navigator.of(context).pushReplacementNamed('/user_home');
      } else {
        setState(() {
          _hasRequest = true;
        });
      }
    });
  }

  Future<void> _cancelRequest(BuildContext context) async {
    if (_isProcessing) return; // Avoid multiple cancellations

    setState(() {
      _isProcessing = true;
    });

    try {
      // Attempt to delete the request
      await _authService.deleteRequest();

      // Navigate to the home page after successful deletion
      Navigator.of(context).pushReplacementNamed('/user_home');
    } catch (e) {
      // Handle errors appropriately
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to cancel request: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  void dispose() {
    _requestStreamSubscription.cancel(); // Cancel the subscription to avoid memory leaks
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    // Prevent back navigation
    return Future.value(false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isProcessing) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Colors.blueAccent,
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(
                  color: Colors.blueAccent,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Waiting for response',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => _cancelRequest(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    minimumSize: const Size(120, 48),
                  ),
                  child: const Text(
                    'Cancel Request',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
