import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Centralized Real-time Network Connectivity & Online/Offline Status Service.
///
/// Monitors network state, broadcasts live connectivity updates, and provides
/// deterministic overrides for automated testing.
class NetworkStatusService {
  static final NetworkStatusService instance = NetworkStatusService._internal();

  NetworkStatusService._internal();

  /// Observable network connectivity status.
  /// Defaults to true (Active/Online) and updates dynamically based on network reachability.
  final ValueNotifier<bool> isOnline = ValueNotifier<bool>(true);

  Timer? _pollTimer;
  bool? _mockIsOnline;

  /// Returns current connectivity value synchronously.
  bool get isConnected => isOnline.value;

  /// Allows unit and widget tests to inject simulated online or offline states.
  @visibleForTesting
  void setMockOnline(bool? mockOnline) {
    _mockIsOnline = mockOnline;
    if (mockOnline != null) {
      isOnline.value = mockOnline;
    }
  }

  /// Manually force a connection state (e.g. from failed/successful network calls).
  void setOnline(bool online) {
    if (_mockIsOnline != null) return;
    if (isOnline.value != online) {
      isOnline.value = online;
    }
  }

  /// Checks internet connectivity using a fast, low-overhead lookup.
  Future<bool> checkConnectivity() async {
    // In headless test environments, use test mock or default to true
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      final effective = _mockIsOnline ?? true;
      if (isOnline.value != effective) {
        isOnline.value = effective;
      }
      return effective;
    }

    try {
      final result = await InternetAddress.lookup('dns.google')
          .timeout(const Duration(seconds: 3));
      final connected = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      if (isOnline.value != connected) {
        isOnline.value = connected;
      }
      return connected;
    } catch (_) {
      try {
        // Fallback secondary lookup
        final fallback = await InternetAddress.lookup('google.com')
            .timeout(const Duration(seconds: 3));
        final connected = fallback.isNotEmpty && fallback[0].rawAddress.isNotEmpty;
        if (isOnline.value != connected) {
          isOnline.value = connected;
        }
        return connected;
      } catch (_) {
        if (isOnline.value != false) {
          isOnline.value = false;
        }
        return false;
      }
    }
  }

  /// Starts periodic background connectivity monitoring.
  void startMonitoring({Duration interval = const Duration(seconds: 10)}) {
    _pollTimer?.cancel();
    // Immediate initial check
    checkConnectivity();
    _pollTimer = Timer.periodic(interval, (_) => checkConnectivity());
  }

  /// Stops background polling.
  void stopMonitoring() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }
}
