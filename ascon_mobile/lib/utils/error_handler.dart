// ascon_mobile/lib/utils/error_handler.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ErrorHandler {
  static void init() {
    // 1. Handle Flutter Framework Errors (Widget build failures)
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint("🔴 Flutter Framework Error: ${details.exception}");
      // Optional: Report to Sentry/Crashlytics here
    };

    // 2. Handle Asynchronous Errors (Futures, Streams)
    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint("🔴 Async Error: $error");
      // Optional: Report to Sentry/Crashlytics here
      return true; // Prevent app crash
    };
    
    // 3. Custom Error Widget for Build Failures
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return Material(
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text(
                "Oops! Something went wrong.",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                kDebugMode ? details.exception.toString() : "We encountered an unexpected error.",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    };
  }
}