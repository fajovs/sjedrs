


import 'package:latlong2/latlong.dart';

class AppConstants {
  static const String mapBoxAccessToken = "pk.eyJ1Ijoic2plZHJzIiwiYSI6ImNsejk0a2xweDAxZmwybXEyMWdvcjJvZGcifQ.BEvOzDJraMvdxKkOZH1wOw";

  static const String urlTemplate = 'https://api.mapbox.com/styles/v1/{id}/tiles/{z}/{x}/{y}?access_token=$mapBoxAccessToken';

  static const String mapBoxStyleStandard = 'mapbox/standard';
  static const String mapBoxStyleDarkId = 'mapbox/dark-v11';
  static const String mapBoxStyleOutdoorId = 'mapbox/outdoors-v12';
  static const String mapBoxStyleStreetId = 'mapbox/streets-v12';
  static const String mapBoxStyleDNightId = 'mapbox/navigation-night-v1';

  static const myLocation = LatLng(51.5, -0.09);

}