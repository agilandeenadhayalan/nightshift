import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class SessionStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class DeviceSessionStore implements SessionStore {
  bool _private(String key) =>
      key == 'token' || key == 'phoneSession' || key == 'deletionReceipt';
  final _secure = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  @override
  Future<String?> read(String key) async => _private(key)
      ? _secure.read(key: key)
      : (await SharedPreferences.getInstance()).getString(key);
  @override
  Future<void> write(String key, String value) async {
    if (_private(key)) {
      await _secure.write(key: key, value: value);
    } else {
      await (await SharedPreferences.getInstance()).setString(key, value);
    }
  }

  @override
  Future<void> delete(String key) async {
    if (_private(key)) {
      await _secure.delete(key: key);
    } else {
      await (await SharedPreferences.getInstance()).remove(key);
    }
  }
}
