import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';



class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final StreamController<Map<String, dynamic>> _requestStreamController = StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _respondStreamController = StreamController.broadcast();

  AuthService() {
    // Start listening to changes in the 'requests' collection
    _database.child('requests').onValue.listen(
          (event) {
        final requestsData = (event.snapshot.value as Map?)?.map(
              (key, value) => MapEntry(
            key as String,
            (value as Map?)?.cast<String, dynamic>() ?? {},
          ),
        ) ?? {};
        _requestStreamController.add(requestsData);
      },
      onError: (error) {
        print('Error listening to requests: $error');
      },
    );

    // Start listening to changes in the 'RespondRequest' collection
    _database.child('RespondRequest').onValue.listen(
          (event) {
        final respondsData = (event.snapshot.value as Map?)?.map(
              (key, value) => MapEntry(
            key as String,
            (value as Map?)?.cast<String, dynamic>() ?? {},
          ),
        ) ?? {};
        _respondStreamController.add(respondsData);
      },
      onError: (error) {
        print('Error listening to RespondRequest: $error');
      },
    );
  }



  // Stream to get real-time updates from the 'requests' collection
  Stream<Map<String, dynamic>> get requestStream => _requestStreamController.stream;

  // Stream to get real-time updates from the 'RespondRequest' collection
  Stream<Map<String, dynamic>> get respondStream => _respondStreamController.stream;


  Future<String> signUpUser({
    required String email,
    required String password,
    required String name,
    String? phone,
  }) async {
    try {
      if (phone != null) {
        final phoneSnapshot = await _database
            .child('users')
            .orderByChild('phone')
            .equalTo(phone)
            .once();

        final phoneSnapshotRes = await _database
            .child('rescuers')
            .orderByChild('phone')
            .equalTo(phone)
            .once();

        if (phoneSnapshot.snapshot.value != null || phoneSnapshotRes.snapshot.value != null) {
          return 'The phone number is already in use by another account.';
        }
      }

      print('Attempting to sign up user with email: $email');
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      print('User created successfully with UID: ${userCredential.user!.uid}');

      try {
        await _database.child('users').child(userCredential.user!.uid).set({
          'email': email,
          'name': name,
          'phone': phone,
        });
        print('User data written to database successfully');
        return 'User signed up successfully';
      } catch (dbError) {
        print('Failed to write data to database: ${dbError.toString()}');
        await userCredential.user!.delete();
        return 'Failed to write data to database. Please try again later.';
      }
    } catch (authError) {
      print('Authentication failed: ${authError.toString()}');
      return 'Registration failed. The email address is already used.';
    }
  }

  Future<String> signUpRescuer({
    required String email,
    required String password,
    required String name,
    String? phone,
  }) async {
    try {
      if (phone != null) {
        final phoneSnapshot = await _database
            .child('users')
            .orderByChild('phone')
            .equalTo(phone)
            .once();

        final phoneSnapshotRes = await _database
            .child('rescuers')
            .orderByChild('phone')
            .equalTo(phone)
            .once();

        if (phoneSnapshot.snapshot.value != null || phoneSnapshotRes.snapshot.value != null) {
          return 'The phone number is already in use by another account.';
        }
      }

      print('Attempting to sign up rescuer with email: $email');
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      print('Rescuer created successfully with UID: ${userCredential.user!.uid}');

      try {
        await _database.child('rescuers').child(userCredential.user!.uid).set({
          'email': email,
          'name': name,
          'phone': phone,
        });
        print('Rescuer data written to database successfully');
        return 'Rescuer signed up successfully';
      } catch (dbError) {
        print('Failed to write data to database: ${dbError.toString()}');
        await userCredential.user!.delete();
        return 'Failed to write data to database. Please try again later.';
      }
    } catch (authError) {
      print('Authentication failed: ${authError.toString()}');
      return 'Registration failed. The email address is already used.';
    }
  }

  Future<String> signInUser({required String email, required String password}) async {
    try {
      print('Attempting to sign in user with email: $email');
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final userId = userCredential.user!.uid;
      print('User signed in successfully with UID: $userId');

      final userSnapshot = await _database.child('users').child(userId).once();
      if (userSnapshot.snapshot.exists) {
        print('User found in database');
        return 'User signed in successfully';
      }

      await _auth.signOut();
      print('User not found in database');
      return 'User not found.';
    } catch (e) {
      print('Sign in failed: ${e.toString()}');
      return 'Sign in failed: Incorrect login credentials.';
    }
  }

  Future<String> signInRescuer({required String email, required String password}) async {
    try {
      print('Attempting to sign in rescuer with email: $email');
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final userId = userCredential.user!.uid;
      print('Rescuer signed in successfully with UID: $userId');

      final rescuerSnapshot = await _database.child('rescuers').child(userId).once();
      if (rescuerSnapshot.snapshot.exists) {
        print('Rescuer found in database');
        return 'Rescuer signed in successfully';
      }

      await _auth.signOut();
      print('Rescuer not found in database');
      return 'Rescuer not found.';
    } catch (e) {
      print('Sign in failed: ${e.toString()}');
      return 'Sign in failed: Incorrect login credentials.';
    }
  }

  Future<String> signOut() async {
    try {
      print('Attempting to sign out');
      await _auth.signOut();
      print('Sign out successful');
      return 'Sign out successful';
    } catch (e) {
      print('Sign out failed: ${e.toString()}');
      return 'Sign out failed: ${e.toString()}';
    }
  }

  Future<void> createRequest() async {
    try {


      print('Attempting to Create Request');
      User? currentUser = getCurrentUser();

      if (currentUser == null) {
        print('No user is currently logged in');
        throw Exception('No user is currently logged in');
      }


      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );


        double latitude = position.latitude;
        double longitude = position.longitude;


      final userSnapshot = await _database.child('users').child(currentUser.uid).once();

      if (userSnapshot.snapshot.exists) {
        // Convert the LinkedMap to a Map<String, dynamic>
        final userData = userSnapshot.snapshot.value as Map<dynamic, dynamic>;
        final convertedUserData = Map<String, dynamic>.from(userData);

        print('User data: $convertedUserData');

        await _database.child('requests').push().set({
          'userId': currentUser.uid,
          'timestamp': DateTime.now().toIso8601String(),
          'userData': convertedUserData,
          'location': {
            'longitude': longitude,
            'latitude': latitude,
          },
        });

        print('Request created successfully');
      } else {
        print('User data not found');
        throw Exception('User data not found');
      }
    } catch (e) {
      print('Request creation failed: ${e.toString()}');
      throw Exception('Request creation failed: ${e.toString()}');
    }
  }


  Future<void> deleteRequest() async {
    try {
      print('Attempting to Delete Request');

      User? currentUser = getCurrentUser();

      if (currentUser == null) {
        print('No user is currently logged in');
        throw Exception('No user is currently logged in');
      }

      final requestsSnapshot = await _database.child('requests').once();

      if (requestsSnapshot.snapshot.exists) {
        final requestsData = (requestsSnapshot.snapshot.value as Map?)?.map(
              (key, value) => MapEntry(
            key as String,
            (value as Map?)?.cast<String, dynamic>() ?? {},
          ),
        ) ?? {};

        final requestToDeleteKey = requestsData.keys.firstWhere(
              (key) => (requestsData[key]?['userId'] as String?) == currentUser.uid,
          orElse: () => '', // Provide a non-nullable default value
        );

        if (requestToDeleteKey.isNotEmpty) {
          await _database.child('requests').child(requestToDeleteKey).remove();
          print('Request deleted successfully');
        } else {
          print('No request found for the current user');
          throw Exception('No request found for the current user');
        }
      } else {
        print('No requests found');
        throw Exception('No requests found');
      }
    } catch (e) {
      print('Request deletion failed: ${e.toString()}');
      throw Exception('Request deletion failed: ${e.toString()}');
    }
  }




  Future<bool> hasRequestForCurrentUser() async {
    try {
      print('Checking if a request exists for the current user');

      User? currentUser = getCurrentUser();

      if (currentUser == null) {
        print('No user is currently logged in');
        throw Exception('No user is currently logged in');
      }

      final requestsSnapshot = await _database.child('requests').once();

      if (requestsSnapshot.snapshot.exists) {
        final requestsData = (requestsSnapshot.snapshot.value as Map?)?.map(
              (key, value) => MapEntry(
            key as String,
            (value as Map?)?.cast<String, dynamic>() ?? {},
          ),
        ) ?? {};

        final requestExists = requestsData.values.any(
              (request) => (request['userId'] as String?) == currentUser.uid,
        );

        print(requestExists);
        return requestExists;
      } else {
        print('No requests found');
        return false;
      }
    } catch (e) {
      print('Failed to check for request: ${e.toString()}');
      throw Exception('Failed to check for request: ${e.toString()}');
    }
  }





  Future<bool> hasAnyRequest() async {
    try {
      print('Checking if there are any requests');

      final requestsSnapshot = await _database.child('requests').once();

      if (requestsSnapshot.snapshot.exists) {
        final requestsData = (requestsSnapshot.snapshot.value as Map?)?.map(
              (key, value) => MapEntry(
            key as String,
            (value as Map?)?.cast<String, dynamic>() ?? {},
          ),
        ) ?? {};

        final anyRequestExists = requestsData.isNotEmpty;

        print('Any request exists: $anyRequestExists');
        return anyRequestExists;
      } else {
        print('No requests found');
        return false;
      }
    } catch (e) {
      print('Failed to check for requests: ${e.toString()}');
      throw Exception('Failed to check for requests: ${e.toString()}');
    }
  }




  Future<bool> hasAccepted() async {
    try {
      print('Checking if a request is Accepted');

      User? currentUser = getCurrentUser();

      if (currentUser == null) {
        print('No user is currently logged in');
        return false;
      }

      final respondsSnapshot = await _database.child('RespondRequest').once();

      if (respondsSnapshot.snapshot.exists) {
        final respondsData = (respondsSnapshot.snapshot.value as Map?)?.map(
              (key, value) => MapEntry(
            key as String,
            (value as Map?)?.cast<String, dynamic>() ?? {},
          ),
        ) ?? {};

        final requestExists = respondsData.values.any(
              (request) => (request['RequesterUserID'] as String?) == currentUser.uid,
        );

        print('Request Accepted: $requestExists');
        return requestExists;
      } else {
        print('No responds found');
        return false;
      }
    } catch (e) {
      print('Failed to check for accepted request: ${e.toString()}');
      return false;
    }
  }




  Future<bool> hasOnProgress() async {
    try {
      print('Checking if there is a request on progress');

      User? currentUser = getCurrentUser();

      if (currentUser == null) {
        print('No user is currently logged in');
        return false;
      }

      final respondsSnapshot = await _database.child('RespondRequest').once();

      if (respondsSnapshot.snapshot.exists) {
        final respondsData = (respondsSnapshot.snapshot.value as Map?)?.map(
              (key, value) => MapEntry(
            key as String,
            (value as Map?)?.cast<String, dynamic>() ?? {},
          ),
        ) ?? {};

        final requestExists = respondsData.values.any(
              (request) => (request['ResponderUserID'] as String?) == currentUser.uid,
        );

        print('Request on progress: $requestExists');
        return requestExists;
      } else {
        print('No responds found');
        return false;
      }
    } catch (e) {
      print('Failed to check for on progress request: ${e.toString()}');
      return false;
    }
  }





  Future<void> deleteSelectedRequest(String requestId) async {
    try {
      // Reference to the specific request node
      final reference = _database.child('requests').child(requestId);
      await reference.remove();
    } catch (e) {
      // Handle error if needed
      print('Failed to delete request: $e');
      rethrow;
    }
  }




  Future<void> updateReposdentLocation() async{
    try {
      User? currentUser = getCurrentUser();
      if (currentUser == null) {
        print('No user is currently logged in');
        throw Exception('No user is currently logged in');
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      double latitude = position.latitude;
      double longitude = position.longitude;

      final userLoc = {
          'longitude' : longitude,
          'latitude' : latitude

      };

      final userRef = _database.child('rescuers').child(currentUser.uid);
      await userRef.update({'location': userLoc});

    } catch (e) {
      print('Failed to update respondent location: $e');
      rethrow;
    }
  }




  Future<void> saveToActiveAndDeleteRequest(String requestId, Map<String, dynamic> requestData) async {
    try {
      User? currentUser = getCurrentUser();
      if (currentUser == null) {
        print('No user is currently logged in');
        throw Exception('No user is currently logged in');
      }

      final newTimestamp = DateFormat('yyyy-MM-ddTHH:mm:ss.SSS').format(DateTime.now());

      if (requestData['userData'] == null || requestData['timestamp'] == null) {
        throw Exception('Invalid request data');
      }

      final updatedRequestData = {
        'RespondTimestamp': newTimestamp,
        'RequestUserData': requestData['userData'],
        'RequestTimestamp': requestData['timestamp'],
        'RequesterUserID': requestData['userId'],
        'RequesterLocation': requestData['location'],
      };

      final userDataSnapshot = await _database.child('rescuers').child(currentUser.uid).get();
      if (userDataSnapshot.exists) {
        final responderUserData = userDataSnapshot.value as Map<dynamic, dynamic>;
        print('Fetched Responder User Data: $responderUserData');

        updatedRequestData['ResponderUserData'] = responderUserData;
        updatedRequestData['ResponderUserID'] = currentUser.uid;
      } else {
        print('User data does not exist for UID: ${currentUser.uid}');
      }

      print('Updated Request Data: $updatedRequestData');
      await updateReposdentLocation();
      final activeRef = _database.child('RespondRequest').child(requestId);
      await activeRef.set(updatedRequestData);
      await deleteSelectedRequest(requestId);


    } catch (e) {
      print('Failed to save and delete request: $e');
      rethrow;
    }
  }





  Future<Map<String, dynamic>?> getFirstResponderData() async {
    try {
      final currentUser = getCurrentUser();
      if (currentUser == null) {
        print('No user is currently logged in.');
        return null;
      }

      final query = _database
          .child('RespondRequest') // Replace with your collection name
          .orderByChild('RequesterUserID')
          .equalTo(currentUser.uid);

      final snapshot = await query.get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;

        // Ensure the data is a Map and has at least one entry
        if (data.isNotEmpty) {
          // Get the first item from the Map without worrying about the key
          final firstItem = data.values.first as Map<dynamic, dynamic>;

          // Extract the required fields
          final responderUserData = firstItem['ResponderUserData'] as Map<dynamic, dynamic>?;
          final responderUserLocation = firstItem['RequesterLocation'] as Map<dynamic, dynamic>?;
          final responderUserID = firstItem['ResponderUserID'] as String?;

          // Return only the specific fields
          return {
            'ResponderUserData': responderUserData,
            'ResponderUserID': responderUserID,
            'RequesterLocation': responderUserLocation,
          };
        } else {
          print('No data found.');
          return null;
        }
      } else {
        print('No documents found.');
        return null;
      }
    } catch (e) {
      // Handle errors (e.g., network issues)
      print("Error getting documents: $e");
      return null;
    }
  }


  Future<Map<String, dynamic>?> getRequesterData() async {
    try {
      final currentUser = getCurrentUser();
      if (currentUser == null) {
        print('No user is currently logged in.');
        return null;
      }

      final query = _database
          .child('RespondRequest') // Replace with your collection name
          .orderByChild('ResponderUserID')
          .equalTo(currentUser.uid);

      final snapshot = await query.get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;

        // Ensure the data is a Map and has at least one entry
        if (data.isNotEmpty) {
          // Get the first item from the Map without worrying about the key
          final firstItem = data.values.first as Map<dynamic, dynamic>;

          // Extract the required fields
          final resquesterUserData = firstItem['RequestUserData'] as Map<dynamic, dynamic>?; // Optional, based on your data structure
          final requesterUserID = firstItem['RequesterUserID'] as String?;

          // Return only the specific fields
          return {
            'ResquestUserData': resquesterUserData,
            'RequesterUserID': requesterUserID,
          };
        } else {
          print('No data found.');
          return null;
        }
      } else {
        print('No documents found.');
        return null;
      }
    } catch (e) {
      // Handle errors (e.g., network issues)
      print("Error getting documents: $e");
      return null;
    }
  }



  Future<void> deleteResponseReq() async {
    try {
      print('Attempting to Delete Response');

      User? currentUser = getCurrentUser();

      if (currentUser == null) {
        print('No user is currently logged in');
        throw Exception('No user is currently logged in');
      }

      final requestsSnapshot = await _database.child('RespondRequest').once();

      if (requestsSnapshot.snapshot.exists) {
        final requestsData = (requestsSnapshot.snapshot.value as Map?)?.map(
              (key, value) => MapEntry(
            key as String,
            (value as Map?)?.cast<String, dynamic>() ?? {},
          ),
        ) ?? {};

        final requestToDeleteKey = requestsData.keys.firstWhere(
              (key) => (requestsData[key]?['RequesterUserID'] as String?) == currentUser.uid,
          orElse: () => '', // Provide a non-nullable default value
        );

        if (requestToDeleteKey.isNotEmpty) {
          await _database.child('RespondRequest').child(requestToDeleteKey).remove();
          print('Request deleted successfully');
        } else {
          print('No request found for the current user');
          throw Exception('No request found for the current user');
        }
      } else {
        print('No requests found');
        throw Exception('No requests found');
      }
    } catch (e) {
      print('Request deletion failed: ${e.toString()}');
      throw Exception('Request deletion failed: ${e.toString()}');
    }
  }

  Future<void> deleteResponseRes() async {
    try {
      print('Attempting to Delete Response');

      final User? currentUser = getCurrentUser();

      if (currentUser == null) {
        print('No user is currently logged in');
        throw Exception('No user is currently logged in');
      }

      final requestsSnapshot = await _database.child('RespondRequest').once();

      if (!requestsSnapshot.snapshot.exists) {
        print('No requests found');
        throw Exception('No requests found');
      }

      final requestsData = (requestsSnapshot.snapshot.value as Map?)?.map(
            (key, value) => MapEntry(
          key as String,
          (value as Map?)?.cast<String, dynamic>() ?? {},
        ),
      ) ?? {};

      final requestToDeleteKey = requestsData.keys.firstWhere(
            (key) => (requestsData[key]?['ResponderUserID'] as String?) == currentUser.uid,
        orElse: () => '',
      );

      if (requestToDeleteKey.isNotEmpty) {
        await _database.child('RespondRequest').child(requestToDeleteKey).remove();
        print('Request deleted successfully');
      } else {
        print('No request found for the current user');
        throw Exception('No request found for the current user');
      }
    } catch (e) {
      print('Request deletion failed: ${e.toString()}');
      throw Exception('Request deletion failed: ${e.toString()}');
    }
  }











  User? getCurrentUser() {
    return FirebaseAuth.instance.currentUser;
  }

  // Dispose of the StreamController when not needed
  void dispose() {
    _requestStreamController.close();
    _respondStreamController.close();
  }
}
