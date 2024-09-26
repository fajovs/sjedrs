import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:sjedrsmobile/src/services/auth_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geolocator;

class RescuerMapScreen extends StatefulWidget {
  const RescuerMapScreen({super.key});

  @override
  State<RescuerMapScreen> createState() => _RescuerMapScreenState();
}

class _RescuerMapScreenState extends State<RescuerMapScreen> {
  final AuthService _authService = AuthService();
  late final StreamSubscription _respondStreamSubscription;
  Timer? _positionUpdateTimer; // Make it nullable
  bool _isLoading = true;
  bool _hasRequest = false;
  double? longitude;
  double? latitude;
  Map<String, dynamic>? _requesterDetails;
  bool _isProcessing = false;
  MapboxMap? mapboxMap;
  PointAnnotation? pointAnnotation;
  PointAnnotationManager? pointAnnotationManager;
  PointAnnotation? currentPointAnnotation;
  PointAnnotationManager? currentPointAnnotationManager;


  @override
  void initState() {
    super.initState();
    _listenToRequestChanges();
    _fetchRescuerDetails();
  }

  void _startListeningToLocation() async {
    // Check and request permissions
    geolocator.LocationPermission permission = await geolocator.Geolocator.checkPermission();
    if (permission == geolocator.LocationPermission.denied) {
      permission = await geolocator.Geolocator.requestPermission();
    }

    if (permission == geolocator.LocationPermission.denied) {
      // Handle permission denied
      return;
    }


    // Start listening for location updates
    geolocator.Geolocator.getPositionStream(
      locationSettings: const geolocator.LocationSettings(
        accuracy: geolocator.LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((geolocator.Position position) {

        _authService.updateReposdentLocation();
        updateCurrentLocation(mapboxMap!);
    });
  }

  Future<void> setCoordinateCamera() async{
    geolocator.Position position = await geolocator.Geolocator.getCurrentPosition(
      desiredAccuracy: geolocator.LocationAccuracy.high,
    );

    double myLatitude = position.latitude;
    double myLongitude = position.longitude;
    if(longitude != null && latitude !=null){


     var dam = await mapboxMap
          ?.cameraForCoordinateBounds(
          CoordinateBounds(
              southwest: Point(
                  coordinates: Position(
                    myLongitude,
                    myLatitude,
                  )),
              northeast: Point(
                  coordinates: Position(
                    longitude!,
                    latitude!,
                  )),
              infiniteBounds: true),
         MbxEdgeInsets(top: 120, left: 120, bottom: 120, right: 120),
          10,
          20,
          null,
          null);

      if(dam != null){
        mapboxMap?.easeTo(dam,MapAnimationOptions(duration: 2000, startDelay: 0));
      }

    }

  }



  void _listenToRequestChanges() {

    _respondStreamSubscription = _authService.respondStream.listen((requestsData) {
      final User? currentUser = _authService.getCurrentUser();

      if (currentUser == null) {
        Navigator.of(context).pushReplacementNamed('/rescuer_login');
        return;
      }

      Map<String, dynamic> requestsMap = Map<String, dynamic>.from(requestsData);
      final hasRequest = requestsMap.values.any(
            (request) => (request['ResponderUserID'] as String?) == currentUser.uid,
      );

      final matchingRequest = requestsMap.values.firstWhere(
            (request) => (request['ResponderUserID'] as String?) == currentUser.uid,
        orElse: () => null,
      );

      if (matchingRequest != null) {
        final requesterLocation = matchingRequest['RequesterLocation'];
        longitude = requesterLocation['longitude'];
        latitude = requesterLocation['latitude'];
      }

      setState(() {
        _isLoading = false;
        _hasRequest = hasRequest;
      });

      if (!hasRequest) {
        Navigator.of(context).pushReplacementNamed('/rescuer_home');
      }
    }, onError: (error) {
      print('Error listening to request stream: $error');
    });
  }




  Future<void> _cancelRequest(BuildContext context) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      await _authService.deleteResponseRes();
      Navigator.of(context).pushReplacementNamed('/rescuer_home');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to cancel request: ${e.toString()}')),
      );
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

  Future<void> _fetchRescuerDetails() async {
    final requesterDetails = await _authService.getRequesterData();
    print('Requester details: $requesterDetails'); // Debug print
    setState(() {
      _requesterDetails = requesterDetails;
    });
  }

  @override
  void dispose() {
    _respondStreamSubscription.cancel();
    _positionUpdateTimer?.cancel(); // Cancel the timer if it exists
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    return Future.value(false);
  }





  Future<void> getRequestPosition(MapboxMap mapboxMap) async {
    if (longitude != null && latitude != null) {

      // mapboxMap.setCamera(CameraOptions(
      //
      //   center: Point(coordinates: Position(longitude!, latitude!)),
      //   zoom: 17.0,
      //
      // ));

      mapboxMap.annotations.createPointAnnotationManager().then((value) async {
        pointAnnotationManager = value;
        final ByteData bytes = await rootBundle.load('assets/symbol/user-location.png');
        final Uint8List list = bytes.buffer.asUint8List();
        createRequestAnnotation(list, longitude!, latitude!);
      });
    }
  }

  Future<void> getCurrentLocation(MapboxMap mapboxMap) async {
    try {
      geolocator.Position position = await geolocator.Geolocator.getCurrentPosition(
        desiredAccuracy: geolocator.LocationAccuracy.high,
      );

      double myLatitude = position.latitude;
      double myLongitude = position.longitude;

      mapboxMap.annotations.createPointAnnotationManager().then((value) async {
        currentPointAnnotationManager = value;
        final ByteData bytes = await rootBundle.load('assets/symbol/rescuer_pin.png');
        final Uint8List list = bytes.buffer.asUint8List();
        createCurrentAnnotation(list, myLongitude, myLatitude);
      });
    } catch (e) {
      print('Error: $e');
    }
  }

  Future<void> updateCurrentLocation(MapboxMap mapboxMap) async {
    try {
      geolocator.Position position = await geolocator.Geolocator.getCurrentPosition(
        desiredAccuracy: geolocator.LocationAccuracy.high,
      );

      double myLatitude = position.latitude;
      double myLongitude = position.longitude;

      if (pointAnnotation != null) {
        var newPoint = Point(coordinates: Position(myLongitude, myLatitude));
        currentPointAnnotation?.geometry = newPoint;
        currentPointAnnotationManager?.update(currentPointAnnotation!);
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    this.mapboxMap = mapboxMap;
    getRequestPosition(mapboxMap);
    getCurrentLocation(mapboxMap);
    _startListeningToLocation();
    setCoordinateCamera();
  }

  void createRequestAnnotation(Uint8List list, double long, double lat) {
    pointAnnotationManager?.create(PointAnnotationOptions(
      geometry: Point(coordinates: Position(long, lat)),
      textOffset: [0.0, -2.0],
      textColor: Colors.red.value,
      iconSize: .5,
      iconOffset: [0.0, -5.0],
      symbolSortKey: 10,
      image: list,
    )).then((value) => pointAnnotation = value);
  }

  void createCurrentAnnotation(Uint8List list, double long, double lat) {
    currentPointAnnotationManager?.create(PointAnnotationOptions(
      geometry: Point(coordinates: Position(long, lat)),
      textOffset: [0.0, -2.0],
      textColor: Colors.red.value,
      iconSize: .5,
      iconOffset: [0.0, -5.0],
      symbolSortKey: 10,
      image: list,
    )).then((value) => currentPointAnnotation = value);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _requesterDetails == null) {
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
                  onMapCreated: _onMapCreated,
                  key: const ValueKey("mapWidget"),
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
                            Text('Name: ${_requesterDetails!['ResquestUserData']['name']}', style: const TextStyle(fontSize: 16)),
                            Text('Email: ${_requesterDetails!['ResquestUserData']['email']}', style: const TextStyle(fontSize: 16)),
                            Text('Phone: ${_requesterDetails!['ResquestUserData']['phone']}', style: const TextStyle(fontSize: 16)),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.phone),
                              color: Colors.blueAccent,
                              onPressed: () {
                                final phoneNumber = _requesterDetails!['ResquestUserData']['phone'] as String;
                                _dialPhoneNumber(phoneNumber);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.message),
                              color: Colors.greenAccent,
                              onPressed: () {
                                final phoneNumber = _requesterDetails!['ResquestUserData']['phone'] as String;
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
