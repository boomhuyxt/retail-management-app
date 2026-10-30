import 'dart:convert';
import 'dart:math';

import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_config.dart';
import 'auth_service.dart';

class BleCredential {
  final String id;
  final String token;
  final DateTime expiresAt;

  final Duration validFor;
  final Stopwatch _age = Stopwatch()..start();

  BleCredential(this.id, this.token, this.expiresAt, this.validFor);

  bool expiresWithin(Duration margin) => _age.elapsed + margin >= validFor;
}

class BleStatus {
  final bool scannerOnline;
  final bool bleReady;
  final String? scannerId;
  final String? lastAction;
  final String? lastShiftName;
  final DateTime? lastAttendanceAt;
  final String? message;

  const BleStatus({
    required this.scannerOnline,
    required this.bleReady,
    this.scannerId,
    this.lastAction,
    this.lastShiftName,
    this.lastAttendanceAt,
    this.message,
  });
}

class BleAttendanceService {
  static final FlutterBlePeripheral _peripheral = FlutterBlePeripheral();
  static const MethodChannel _backgroundChannel = MethodChannel(
    'com.example.mobile/ble_presence',
  );
  static const String _deviceKey = 'ble_device_installation_id';
  static const String _autoEnabledKey = 'ble_auto_attendance_enabled';
  BleCredential? _credential;
  bool _advertising = false;
  Future<void> _operation = Future<void>.value();
  String? _checkoutKey;
  DateTime? _retryAfter;

  void _checkCooldown() {
    final until = _retryAfter;
    if (until != null && DateTime.now().isBefore(until)) {
      throw StateError(
        'API đang giới hạn yêu cầu. Vui lòng chờ ${until.difference(DateTime.now()).inSeconds + 1} giây rồi thử lại.',
      );
    }
  }

  Future<T> _exclusive<T>(Future<T> Function() work) {
    final result = _operation.then((_) => work());
    _operation = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return result;
  }

  bool get isAdvertising => _advertising;
  Future<bool> get autoAttendanceEnabled async =>
      (await SharedPreferences.getInstance()).getBool(_autoEnabledKey) ?? false;

  Future<void> startPresence() => _exclusive(() async {
    if (!await _peripheral.isSupported) {
      throw StateError('Thiết bị không hỗ trợ phát BLE. Hãy dùng QR.');
    }
    var permission = await _peripheral.hasPermission();
    if (permission.name != 'granted' && permission.name != 'ready') {
      permission = await _peripheral.requestPermission();
    }
    if (permission.name != 'granted' && permission.name != 'ready') {
      throw StateError('Bluetooth chưa sẵn sàng hoặc chưa được cấp quyền.');
    }
    try {
      await _issueCredentialAndAdvertise();
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _backgroundChannel.invokeMethod<void>('startForeground');
      }
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_autoEnabledKey, true);
    } catch (_) {
      await _peripheral.stop();
      _advertising = false;
      rethrow;
    }
  });

  Future<void> _issueCredentialAndAdvertise() async {
    _checkCooldown();
    final preferences = await SharedPreferences.getInstance();
    var deviceId = preferences.getString(_deviceKey);
    if (deviceId == null) {
      final random = Random.secure();
      deviceId = List<int>.generate(
        24,
        (_) => random.nextInt(256),
      ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();
      await preferences.setString(_deviceKey, deviceId);
    }
    final requestAge = Stopwatch()..start();
    final response = await AuthService.authenticatedRequest(
      (token) => http
          .post(
            Uri.parse(
              '${ApiConfig.baseUrl}/api/attendance/ble/presence-credentials',
            ),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'deviceId': deviceId}),
          )
          .timeout(const Duration(seconds: 12)),
    );
    final data = _decode(response);
    if (response.statusCode != 200) {
      throw StateError(
        data['title']?.toString() ?? 'Không cấp được BLE credential.',
      );
    }

    final expiresAt = DateTime.parse(data['expiresAtUtc'].toString());
    // A phone's wall clock may differ from the API clock. Anchor the lease
    // to the server's HTTP Date and track elapsed time monotonically.
    Duration validFor;
    try {
      final serverTime = DateFormat(
        "EEE, dd MMM yyyy HH:mm:ss 'GMT'",
        'en_US',
      ).parseUtc(response.headers['date']!);
      validFor =
          expiresAt.difference(serverTime) -
          requestAge.elapsed -
          const Duration(seconds: 2);
    } catch (_) {
      validFor =
          Duration(
            seconds: (data['refreshAfterSeconds'] as num?)?.toInt() ?? 60,
          ) -
          requestAge.elapsed;
    }
    final credential = BleCredential(
      data['credentialId'].toString(),
      data['advertisementToken'].toString(),
      expiresAt,
      validFor,
    );
    final previousCredential = _credential;
    _advertising = false;
    _credential = null;
    await _peripheral.stop();
    if (previousCredential != null) {
      await _revokeCredential(previousCredential.id);
    }
    final result = await _peripheral.start(
      advertiseData: AdvertiseDataCore(serviceUuid: credential.token),
    );
    if (result.name != 'ready') {
      await _revokeCredential(credential.id);
      throw StateError('Không thể phát BLE (${result.name}). Hãy dùng QR.');
    }
    _credential = credential;
    _advertising = true;
  }

  Future<void> refreshPresence() => _exclusive(() async {
    if (_advertising &&
        (_credential == null ||
            _credential!.expiresWithin(const Duration(seconds: 65)))) {
      await _issueCredentialAndAdvertise();
    }
  });

  Future<BleStatus> status() async {
    _checkCooldown();
    final response = await AuthService.authenticatedRequest(
      (token) => http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/api/attendance/ble/me/status'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 10)),
    );
    final data = _decode(response);
    if (response.statusCode != 200) {
      throw StateError(
        data['title']?.toString() ?? 'Không tải được trạng thái BLE.',
      );
    }
    return BleStatus(
      scannerOnline: data['scannerOnline'] == true,
      bleReady: data['bleReady'] == true,
      scannerId: data['scannerId']?.toString(),
      lastAction: data['lastAction']?.toString(),
      lastShiftName: data['lastShiftName']?.toString(),
      lastAttendanceAt: DateTime.tryParse(
        data['lastAttendanceAtUtc']?.toString() ?? '',
      )?.toLocal(),
      message: data['message']?.toString(),
    );
  }

  Future<Map<String, dynamic>> checkout(
    int? shiftAssignmentId,
  ) => _exclusive(() async {
    _checkCooldown();
    final credential = _credential;
    if (!_advertising || credential == null) {
      throw StateError(
        'BLE chưa phát tín hiệu. Hãy bật tự động trước khi check-out.',
      );
    }
    if (credential.expiresWithin(const Duration(seconds: 15))) {
      await _issueCredentialAndAdvertise();
      throw StateError(
        'BLE vừa được làm mới. Hãy đứng gần kiosk ít nhất 20 giây rồi bấm Check-out lại.',
      );
    }
    final currentStatus = await status();
    if (!currentStatus.scannerOnline || currentStatus.scannerId == null) {
      throw StateError('Kiosk BLE chưa sẵn sàng. Hãy dùng QR.');
    }
    final checkoutKey = _checkoutKey ??= _randomId();
    final response = await AuthService.authenticatedRequest(
      (token) => http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/api/attendance/ble/checkout'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'shiftAssignmentId': shiftAssignmentId,
              'credentialId': credential.id,
              'presenceToken': credential.token,
              'idempotencyKey': checkoutKey,
              'scannerId': currentStatus.scannerId,
            }),
          )
          .timeout(const Duration(seconds: 12)),
    );
    final data = _decode(response);
    if (response.statusCode != 200) {
      throw StateError(
        data['title']?.toString() ?? 'Check-out BLE không thành công.',
      );
    }
    _checkoutKey = null;
    await _stopPresence();
    return data;
  });

  Future<void> stopPresence() => _exclusive(_stopPresence);

  Future<void> _stopPresence() async {
    if (_advertising) {
      await _peripheral.stop();
    }
    _advertising = false;
    final credential = _credential;
    _credential = null;
    if (credential != null) {
      await _revokeCredential(credential.id);
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_autoEnabledKey, false);
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _backgroundChannel.invokeMethod<void>('stopForeground');
      } on PlatformException {
        // The platform service may already have been stopped by Android.
      } on MissingPluginException {
        // The host activity can disappear while the service is being stopped.
      }
    }
  }

  Future<void> _revokeCredential(String credentialId) async {
    try {
      await AuthService.authenticatedRequest(
        (token) => http
            .delete(
              Uri.parse(
                '${ApiConfig.baseUrl}/api/attendance/ble/presence-credentials/$credentialId',
              ),
              headers: {'Authorization': 'Bearer $token'},
            )
            .timeout(const Duration(seconds: 8)),
      );
    } catch (_) {
      // Expiration remains the fallback if the network is unavailable.
    }
  }

  static String _randomId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    final hex = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-4${hex.substring(13, 16)}-a${hex.substring(17, 20)}-${hex.substring(20)}';
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode == 429) {
      final seconds = int.tryParse(response.headers['retry-after'] ?? '') ?? 60;
      _retryAfter = DateTime.now().add(Duration(seconds: seconds));
      _checkCooldown();
    }
    try {
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }
}
