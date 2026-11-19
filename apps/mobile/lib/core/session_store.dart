import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class SessionStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class DeviceSessionStore implements SessionStore {
  final _secure = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  @override
  Future<String?> read(String key) async => key == 'token'
      ? _secure.read(key: key)
      : (await SharedPreferences.getInstance()).getString(key);
  @override
  Future<void> write(String key, String value) async {
    if (key == 'token') {
      await _secure.write(key: key, value: value);
    } else {
      await (await SharedPreferences.getInstance()).setString(key, value);
    }
  }

  @override
  Future<void> delete(String key) async {
    if (key == 'token') {
      await _secure.delete(key: key);
    } else {
      await (await SharedPreferences.getInstance()).remove(key);
    }
  }
}
