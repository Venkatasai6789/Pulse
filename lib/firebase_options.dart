// File generated or configured for Firebase.
// When you run `flutterfire configure --project=<your-project-id> --platforms=android`,
// this file is populated with your exact project configuration.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDemoPlaceholderWebKey',
    appId: '1:123456789012:web:demo',
    messagingSenderId: '123456789012',
    projectId: 'pulse-app',
    authDomain: 'pulse-app.firebaseapp.com',
    storageBucket: 'pulse-app.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAjZZ183kwN2-x6aRGnNXIOMt3Rz_JWQTA',
    appId: '1:699720500665:android:67f4a6d043ad9fa7d62268',
    messagingSenderId: '699720500665',
    projectId: 'pulse-app-849c6',
    storageBucket: 'pulse-app-849c6.firebasestorage.app',
  );
}
