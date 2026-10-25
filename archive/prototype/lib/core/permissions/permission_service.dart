import 'package:permission_handler/permission_handler.dart';
import '../utils/app_logger.dart';

class PermissionService {
  /// Request all mandatory permissions for P2P mesh networking:
  /// Bluetooth (Scan, Advertise, Connect) and Location
  static Future<bool> requestMeshPermissions() async {
    AppLogger.info('Requesting Bluetooth & Location permissions for P2P mesh...');

    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
      Permission.nearbyWifiDevices,
    ].request();

    bool allGranted = true;
    statuses.forEach((permission, status) {
      AppLogger.info('$permission: ${status.name}');
      if (status.isPermanentlyDenied || status.isDenied) {
        allGranted = false;
      }
    });

    return allGranted;
  }

  static Future<bool> areMeshPermissionsGranted() async {
    final btScan = await Permission.bluetoothScan.isGranted;
    final btAdv = await Permission.bluetoothAdvertise.isGranted;
    final btConn = await Permission.bluetoothConnect.isGranted;
    final loc = await Permission.locationWhenInUse.isGranted;

    return (btScan && btAdv && btConn) || loc;
  }
}
