import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:sjedrsmobile/src/screens/home_screen.dart';
import 'package:sjedrsmobile/src/screens/login_screen.dart';
import 'package:sjedrsmobile/src/screens/map.dart';
import 'package:sjedrsmobile/src/screens/register_screen.dart';
import 'package:sjedrsmobile/src/screens/rescuer_home_screen.dart';
import 'package:sjedrsmobile/src/screens/rescuer_login_screen.dart';
import 'package:sjedrsmobile/src/screens/rescuer_map_screen.dart';
import 'package:sjedrsmobile/src/screens/rescuer_register_screen.dart';
import 'package:sjedrsmobile/src/screens/user_map_screen.dart';
import 'package:sjedrsmobile/src/screens/user_waiting_screen.dart';
import 'firebase_options.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );


  MapboxOptions.setAccessToken("pk.eyJ1Ijoic2plZHJzIiwiYSI6ImNsejk0a2xweDAxZmwybXEyMWdvcjJvZGcifQ.BEvOzDJraMvdxKkOZH1wOw");

  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SJEDRS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.red,
      ),
      home: const LoginScreen(),
      routes: {

        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/user_waiting': (context) => const UserWaitingScreen(),
        '/rescuer_login': (context) => const RescuerLoginScreen(),
        '/rescuer_register': (context) => const RescuerRegisterScreen(),
        '/user_home': (context) => HomeScreen(),
        '/rescuer_home': (context) => const RescuerHomeScreen(),
        '/rescuer_map': (context) => const RescuerMapScreen(),
        '/user_map': (context) =>  const UserMapScreen(),
        '/map': (context) => const MapPage(),


      },
    );
  }
}
