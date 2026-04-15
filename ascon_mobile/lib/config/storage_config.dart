import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageConfig {
  // ✅ Configured for FlutterSecureStorage v10
  static const AndroidOptions androidOptions = AndroidOptions(
    encryptedSharedPreferences: true, 
  );

  static const FlutterSecureStorage storage = FlutterSecureStorage(
    aOptions: androidOptions,
  );
}