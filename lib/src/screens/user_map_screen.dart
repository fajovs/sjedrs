import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart' as geolocator;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sjedrsmobile/src/services/auth_service.dart';
import 'package:url_launcher/url_launcher.dart';

class UserMapScreen extends StatefulWidget {
  const UserMapScreen({super.key});

  @override
  State<UserMapScreen> createState() => _UserMapScreenState();
}

class _UserMapScreenState extends State<UserMapScreen> {
  final AuthService _authService = AuthService();
  StreamSubscription? _respondStreamSubscription;
  bool _isLoading = true;
  bool _isProcessing = false;
  bool _hasRespond = false;
  double? respondLatitude;
  double? respondLongitude;
  Map<String, dynamic>? _userDetails;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  MapboxMap? mapboxMap;
  PointAnnotation? pointAnnotation;
  PointAnnotation? responderPointAnnotation;
  PointAnnotationManager? pointAnnotationManager;
  PointAnnotationManager? responderPointAnnotationManager;

  @override
  void initState() {
    super.initState();
    _fetchUserDetails();
    _checkLocationServiceAndPermission();
    fetchRescuerData();
    _listenToRescuerLocationChanges();
  }

  Future<void> _fetchUserDetails() async {
    try {
      final userDetails = await _authService.getFirstResponderData();
      if (userDetails != null) {
        setState(() {
          _userDetails = userDetails;
        });
        _listenToRequestChanges();

      } else {
        _navigateToHome();
      }
    } catch (e) {
      _handleError('Failed to fetch user details: $e');
    }
  }

  void _listenToRescuerLocationChanges() async {
    final userID = await _authService.getFirstResponderData();
    if (userID != null) {
      _database.child('rescuers').child(userID['ResponderUserID']).child('location').onValue.listen((event) {
        if (event.snapshot.exists) {
          final data = event.snapshot.value as Map<dynamic, dynamic>?;

          if (data != null) {
            final longitude = data['longitude'];
            final latitude = data['latitude'];

            if (longitude != null && latitude != null) {
              respondLongitude = longitude;
              respondLatitude = latitude;

              if (mapboxMap != null) {
                updateLocation(mapboxMap!, respondLongitude!, respondLatitude!);
              } else {
                print('MapboxMap is null, cannot update location.');
              }
            } else {
              print('Location data is null or incomplete.');
            }
          } else {
            print('Location data is null.');
          }
        } else {
          print('No data found for the specified ResponderUserID.');
        }
      }, onError: (error) {
        print('Error listening to rescuer location changes: $error');
      });
    }
  }







  void _listenToRequestChanges() {
    _respondStreamSubscription = _authService.respondStream.listen(
          (respondsData) {
        final User? currentUser = _authService.getCurrentUser();
        if (currentUser == null) {
          _navigateToHome();
          return;
        }

        final hasRespond = respondsData.values.any((request) => request['RequesterUserID'] == currentUser.uid);
        setState(() {
          _isLoading = false;
          _hasRespond = hasRespond;
        });

        if (!hasRespond) {
          _navigateToHome();
        }
      },
      onError: (error) {
        print('Error listening to respond stream: $error');
      },
      onDone: () {
        print('Respond stream closed.');
      },
    );
  }


  Future<Map<String, dynamic>?> fetchRescuerData() async {
    try {
      final responderDetails = await _authService.getFirstResponderData();
      if (_userDetails == null || _userDetails!['ResponderUserID'] == null) {
        print('User details or ResponderUserID is null.');
        return null;
      }

      DataSnapshot snapshot = await _database.child('rescuers').child(responderDetails!['ResponderUserID']).get();

      if (snapshot.exists) {
        print('Snapshot data: ${snapshot.value}');
        return Map<String, dynamic>.from(snapshot.value as Map<Object?, Object?>);
      } else {
        print('No data found for the specified ResponderUserID.');
        return null;
      }
    } catch (e) {
      print('Error fetching rescuer data: $e');
      return null;
    }
  }


  void _navigateToHome() {
    Navigator.of(context).pushReplacementNamed('/user_home');
  }

  void _handleError(String message) {
    print(message);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _checkLocationServiceAndPermission() async {
    while (true) {
      bool serviceEnabled = await geolocator.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationServiceAlert();
        return;
      }

      var permission = await Permission.location.request();
      if (permission.isGranted) {
        break;
      } else if (permission.isDenied) {
        _showPermissionDeniedAlert();
        return;
      }

      await Future.delayed(const Duration(seconds: 2));
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
                await Future.delayed(const Duration(seconds: 2));
                _checkLocationServiceAndPermission();
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

  Future<void> setCoordinateCamera() async {
    try {
      if (respondLongitude != null && respondLatitude != null) {
        var bounds = CoordinateBounds(
          southwest: Point(
            coordinates: Position(
              respondLongitude!,
              respondLatitude!,
            ),
          ),
          northeast: Point(
            coordinates: Position(
              _userDetails!['RequesterLocation']['longitude'],
              _userDetails!['RequesterLocation']['latitude'],
            ),
          ),
          infiniteBounds: true,
        );

        var dam = await mapboxMap?.cameraForCoordinateBounds(
          bounds,
          MbxEdgeInsets(top: 120, left: 120, bottom: 120, right: 120),
          10,
          20,
          null,
          null,
        );

        if (dam != null) {
          await mapboxMap?.easeTo(dam, MapAnimationOptions(duration: 2000, startDelay: 0));
        } else {
          print("Camera calculation returned null.");
        }
      } else {
        print("Longitude or latitude is null.");
      }
    } catch (e) {
      print("An error occurred while setting the camera: $e");
    }
  }


  Future<void> updateLocation(MapboxMap mapboxMap, double longitude, double latitude) async {
    try {
      if (responderPointAnnotation != null) {
        var newPoint = Point(coordinates: Position(longitude, latitude));
        responderPointAnnotation?.geometry = newPoint;
        responderPointAnnotationManager?.update(responderPointAnnotation!);
      }
    } catch (e) {
      print('Error setting location: $e');
    }
  }

  Future<void> responderLocation(MapboxMap mapboxMap) async {
    try {

      final responderData = await fetchRescuerData();
      respondLongitude = responderData!['location']['longitude'];
      respondLatitude = responderData!['location']['latitude'];


      if (respondLongitude == null || respondLatitude == null) {
        print('Invalid responder location data');
        return;
      }

      responderPointAnnotationManager = await mapboxMap.annotations.createPointAnnotationManager();

      final ByteData bytes = await rootBundle.load('assets/symbol/rescuer_pin.png');
      final Uint8List list = bytes.buffer.asUint8List();

      createResponderAnnotation(list, respondLongitude!, respondLatitude!);
    } catch (e) {
      print('Error setting location: $e');
    }
  }




  Future<void> getRequestLocation(MapboxMap mapboxMap) async {
    try {
      if (_userDetails != null) {
        double latitude = _userDetails!['RequesterLocation']['latitude'];
        double longitude = _userDetails!['RequesterLocation']['longitude'];


        pointAnnotationManager = await mapboxMap.annotations.createPointAnnotationManager();
        final ByteData bytes = await rootBundle.load('assets/symbol/user-location.png');
        final Uint8List list = bytes.buffer.asUint8List();
        createRequestAnnotation(list, longitude, latitude);
      }
    } catch (e) {
      print('Error setting location: $e');
    }
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    this.mapboxMap = mapboxMap;

    await getRequestLocation(mapboxMap);
    await responderLocation(mapboxMap);
    await setCoordinateCamera();
  }


  void createResponderAnnotation(Uint8List list, double long, double lat) {
    responderPointAnnotationManager?.create(PointAnnotationOptions(
      geometry: Point(coordinates: Position(long, lat)),
      textOffset: [0.0, -2.0],
      textColor: Colors.red.value,
      iconSize: 0.5,
      iconOffset: [0.0, -5.0],
      symbolSortKey: 10,
      image: list,
    )).then((value) => responderPointAnnotation = value);
  }

  void createRequestAnnotation(Uint8List list, double long, double lat) {
    pointAnnotationManager?.create(PointAnnotationOptions(
      geometry: Point(coordinates: Position(long, lat)),
      textOffset: [0.0, -2.0],
      textColor: Colors.red.value,
      iconSize: 0.5,
      iconOffset: [0.0, -5.0],
      symbolSortKey: 10,
      image: list,
    )).then((value) => pointAnnotation = value);
  }

  Future<void> _cancelRequest(BuildContext context) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      await _authService.deleteResponseReq();
      _navigateToHome();
    } catch (e) {
      _handleError('Failed to cancel request: ${e.toString()}');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _dialPhoneNumber(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      print('Could not launch phone URI');
    }
  }

  void _sendMessage(String phoneNumber) async {
    final Uri smsUri = Uri(scheme: 'sms', path: phoneNumber);
    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri);
    } else {
      print('Could not launch SMS URI');
    }
  }

  @override
  void dispose() {
    _respondStreamSubscription?.cancel();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    return Future.value(false); // Prevent back navigation
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _userDetails == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Colors.blueAccent),
        ),
      );
    }

    if (_isProcessing) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Colors.blueAccent),
        ),
      );
    }

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: MapWidget(
                  key: const ValueKey("mapWidget"),
                  onMapCreated: _onMapCreated,
                ),
              ),
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    color: Colors.grey[200],
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Name: ${_userDetails!['ResponderUserData']['name']}', style: const TextStyle(fontSize: 16)),
                            Text('Email: ${_userDetails!['ResponderUserData']['email']}', style: const TextStyle(fontSize: 16)),
                            Text('Phone: ${_userDetails!['ResponderUserData']['phone']}', style: const TextStyle(fontSize: 16)),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.phone),
                              color: Colors.blueAccent,
                              onPressed: () {
                                final phoneNumber = _userDetails!['ResponderUserData']['phone'] as String;
                                _dialPhoneNumber(phoneNumber);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.message),
                              color: Colors.greenAccent,
                              onPressed: () {
                                final phoneNumber = _userDetails!['ResponderUserData']['phone'] as String;
                                _sendMessage(phoneNumber);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            setCoordinateCamera();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
                          ),
                          icon: const Icon(Icons.update),
                          label: const Text('Update Position', style: TextStyle(fontSize: 16)),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _cancelRequest(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
                          ),
                          icon: const Icon(Icons.close),
                          label: const Text('Close', style: TextStyle(fontSize: 16)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
