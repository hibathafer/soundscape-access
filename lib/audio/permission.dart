import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

/// Permission flow per prd.md > States and Boundaries:
/// gentle one-line explanation (owned by the UI) -> system dialog ->
/// denied => friendly message + route to settings.
class MicPermission {
  static Future<bool> isGranted() async =>
      (await Permission.microphone.status).isGranted;

  static Future<bool> isNotificationGranted() async {
    if (!Platform.isAndroid) return true;
    return (await Permission.notification.status).isGranted;
  }

  /// Returns true when the system dialog was shown and granted.
  /// `permanentlyDenied` is reported back so the UI can offer Settings.
  static Future<PermissionResult> request() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) return PermissionResult.granted;
    if (status.isPermanentlyDenied) return PermissionResult.permanentlyDenied;
    return PermissionResult.denied;
  }

  static Future<PermissionResult> requestNotification() async {
    if (!Platform.isAndroid) return PermissionResult.granted;

    final status = await Permission.notification.request();
    if (status.isGranted) return PermissionResult.granted;
    if (status.isPermanentlyDenied) return PermissionResult.permanentlyDenied;
    return PermissionResult.denied;
  }

  static Future<void> openSettings() => openAppSettings();
}

enum PermissionResult { granted, denied, permanentlyDenied }
