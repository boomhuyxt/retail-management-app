import 'dart:async';

import 'package:geolocator/geolocator.dart';

class AttendancePosition {
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime capturedAtUtc;
  final bool isMocked;

  const AttendancePosition({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.capturedAtUtc,
    required this.isMocked,
  });

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'accuracyMeters': accuracyMeters,
    'capturedAtUtc': capturedAtUtc.toIso8601String(),
    'isMocked': isMocked,
  };
}

class AttendanceLocationException implements Exception {
  final String code;
  final String message;

  const AttendanceLocationException(this.code, this.message);

  @override
  String toString() => message;
}

class AttendanceLocationService {
  static Future<AttendancePosition> getCurrentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const AttendanceLocationException(
        'location_service_disabled',
        'GPS đang tắt. Vui lòng bật dịch vụ vị trí rồi thử lại.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const AttendanceLocationException(
        'location_permission_denied',
        'Bạn cần cấp quyền vị trí để chấm công.',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      throw const AttendanceLocationException(
        'location_permission_denied_forever',
        'Quyền vị trí đã bị từ chối vĩnh viễn. Vui lòng bật lại trong Cài đặt ứng dụng.',
      );
    }

    final accuracyStatus = await Geolocator.getLocationAccuracy();
    if (accuracyStatus == LocationAccuracyStatus.reduced) {
      throw const AttendanceLocationException(
        'precise_location_required',
        'Vui lòng bật Vị trí chính xác để chấm công.',
      );
    }

    try {
      const settings = LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      );
      final position = await Geolocator.getCurrentPosition(
        locationSettings: settings,
      );

      return AttendancePosition(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
        capturedAtUtc: position.timestamp.toUtc(),
        isMocked: position.isMocked,
      );
    } on TimeoutException {
      throw const AttendanceLocationException(
        'location_timeout',
        'Không lấy được GPS trong 15 giây. Hãy ra nơi thoáng hơn rồi thử lại.',
      );
    } catch (error) {
      if (error is AttendanceLocationException) rethrow;
      throw const AttendanceLocationException(
        'location_unavailable',
        'Không thể xác định vị trí GPS. Vui lòng kiểm tra lại dịch vụ vị trí trên thiết bị.',
      );
    }
  }

  static Future<bool> openAppSettings() => Geolocator.openAppSettings();

  static Future<bool> openLocationSettings() =>
      Geolocator.openLocationSettings();
}
