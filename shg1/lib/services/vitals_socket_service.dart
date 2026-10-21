import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class VitalsSocketService {
  VitalsSocketService._();
  static final VitalsSocketService instance = VitalsSocketService._();

  IO.Socket? _socket;
  final ValueNotifier<Map<String, dynamic>?> vitalsNotifier = ValueNotifier(null);
  final ValueNotifier<Map<String, dynamic>?> emergencyAlertNotifier = ValueNotifier(null);
  final ValueNotifier<bool> isConnectedNotifier = ValueNotifier(false);

  /// Emitted by server every minute with IDs of reminders whose
  /// repeat_to_date has passed. Shape: { 'expiredIds': ['id1', 'id2', ...] }
  final ValueNotifier<List<String>> reminderExpiredNotifier = ValueNotifier([]);

  void initSocket({String serverUrl = 'http://127.0.0.1:5000'}) {
    if (_socket != null) return;

    try {
      _socket = IO.io(
        serverUrl,
        IO.OptionBuilder()
            .setTransports(['polling', 'websocket']) // polling first fixes Flutter Web WebSocket errors
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(10)
            .setReconnectionDelay(2000)
            .disableForceNew()
            .build(),
      );

      _socket!.onConnect((_) {
        debugPrint('⚡ Socket.IO connected to $serverUrl');
        isConnectedNotifier.value = true;
      });

      _socket!.onConnectError((err) {
        debugPrint('⚠️ Socket.IO connect error: $err');
        isConnectedNotifier.value = false;
      });

      _socket!.onDisconnect((_) {
        debugPrint('🔌 Socket.IO disconnected');
        isConnectedNotifier.value = false;
      });

      _socket!.on('vitals_update', (data) {
        debugPrint('📡 Real-time Socket.IO Vitals update received: $data');
        if (data is Map) {
          vitalsNotifier.value = Map<String, dynamic>.from(data);
        }
      });

      _socket!.on('emergency_alert', (data) {
        debugPrint('🚨 Real-time Socket.IO Emergency Alert received: $data');
        if (data is Map) {
          emergencyAlertNotifier.value = Map<String, dynamic>.from(data);
        }
      });

      _socket!.on('reminder_expired', (data) {
        debugPrint('🗑️ Socket.IO reminder_expired received: $data');
        if (data is Map && data['expiredIds'] is List) {
          reminderExpiredNotifier.value =
              List<String>.from(data['expiredIds'] as List);
        }
      });
    } catch (e) {
      debugPrint('❌ Socket.IO connection error: $e');
    }
  }

  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
