import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Safe Crashlytics wrapper that initializes Firebase Crashlytics when
/// native Firebase configuration (`google-services.json` / `GoogleService-Info.plist`)
/// is present, and degrades gracefully in local dev or CI builds without it.
abstract final class CrashReporter {
  static bool _isInitialized = false;

  static bool get isInitialized => _isInitialized;

  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
        !kDebugMode,
      );
      _isInitialized = true;
    } catch (_) {
      // Firebase native config (google-services.json) not yet added;
      // continue without Crashlytics so dev/test builds work out of the box.
      _isInitialized = false;
    }

    final FlutterExceptionHandler? priorFlutterOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (_isInitialized) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      } else if (priorFlutterOnError != null) {
        priorFlutterOnError(details);
      } else {
        FlutterError.presentError(details);
      }
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      if (_isInitialized) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      }
      return true;
    };
  }

  static Future<void> recordNonFatal(
    Object error,
    StackTrace stackTrace, {
    String? reason,
  }) async {
    if (!_isInitialized) {
      return;
    }
    try {
      await FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: reason,
        fatal: false,
      );
    } catch (_) {
      // Ignore reporting failures.
    }
  }
}
