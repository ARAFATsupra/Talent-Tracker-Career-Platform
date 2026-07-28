// File generated manually using values from the Firebase Console
// (Project Settings -> Your apps) since `flutterfire configure`
// requires a CLI login that wasn't completing successfully in this
// environment.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD0CHuNZ8sP_-JJl8QW-FmwIdqnOqrlqqw',
    appId: '1:127786425302:android:2d8a138bb02becdb24e277',
    messagingSenderId: '127786425302',
    projectId: 'talent-tracker-ai-dev',
    storageBucket: 'talent-tracker-ai-dev.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyChG67j2FRUrCDOut7wflD2nkJ32rF3Qek',
    appId: '1:127786425302:web:35cab80101d13fb324e277',
    messagingSenderId: '127786425302',
    projectId: 'talent-tracker-ai-dev',
    authDomain: 'talent-tracker-ai-dev.firebaseapp.com',
    storageBucket: 'talent-tracker-ai-dev.firebasestorage.app',
    measurementId: 'G-MEMX485R3S',
  );
}