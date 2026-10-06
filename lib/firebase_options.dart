// Firebase project "B Music" used for instant (FCM) announcements.
//
// These values are not secrets: they identify the app to Firebase and ship in
// every APK. tool/configure_android.py copies them into Android string
// resources so the native FirebaseApp matches the one Dart initialises.
// Empty appId/apiKey = not configured: push stays off and the
// announcements.json poll is the only delivery path.
import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: '',
    appId: '',
    messagingSenderId: '',
    projectId: '',
  );

  static bool get configured =>
      android.appId.isNotEmpty && android.apiKey.isNotEmpty;
}
