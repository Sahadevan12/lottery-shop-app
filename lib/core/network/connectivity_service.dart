import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

final Provider<Future<bool> Function()> reachabilityProbeProvider =
    Provider<Future<bool> Function()>((Ref ref) {
  return ConnectivityController.defaultProbe;
});

final Provider<bool> enablePeriodicOfflineProbeProvider = Provider<bool>((Ref ref) {
  return !Platform.environment.containsKey('FLUTTER_TEST');
});

final NotifierProvider<ConnectivityController, bool> isOnlineProvider =
    NotifierProvider<ConnectivityController, bool>(ConnectivityController.new);

class ConnectivityController extends Notifier<bool> {
  static const Duration offlinePollInterval = Duration(seconds: 15);
  Timer? _offlinePollTimer;

  @override
  bool build() {
    ref.onDispose(_cancelPollTimer);
    return true;
  }

  void _cancelPollTimer() {
    _offlinePollTimer?.cancel();
    _offlinePollTimer = null;
  }

  void _startPollTimerIfNeeded() {
    if (!ref.read(enablePeriodicOfflineProbeProvider)) {
      return;
    }
    if (_offlinePollTimer != null && _offlinePollTimer!.isActive) {
      return;
    }
    _offlinePollTimer = Timer.periodic(offlinePollInterval, (_) {
      probeOnline();
    });
  }

  void markOnline() {
    _cancelPollTimer();
    if (!state) {
      state = true;
    }
  }

  void markOffline() {
    if (state) {
      state = false;
    }
    _startPollTimerIfNeeded();
  }

  /// Returns `true` when [error] indicates a network / connectivity failure
  /// rather than a business-rule RPC exception or missing SupabaseConfig.
  static bool isNetworkError(Object error) {
    if (error is SocketException ||
        error is HandshakeException ||
        error is TimeoutException ||
        error is HttpException) {
      return true;
    }
    final String msg = error.toString().toLowerCase();
    return msg.contains('socketexception') ||
        msg.contains('failed host lookup') ||
        msg.contains('connection refused') ||
        msg.contains('connection reset') ||
        msg.contains('network is unreachable') ||
        msg.contains('clientexception') ||
        msg.contains('xmlhttprequest error');
  }

  static Future<bool> defaultProbe() async {
    try {
      final List<InternetAddress> result =
          await InternetAddress.lookup('supabase.co')
              .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> probeOnline() async {
    try {
      final Future<bool> Function() probe = ref.read(reachabilityProbeProvider);
      final bool online = await probe();
      if (online) {
        markOnline();
      } else {
        markOffline();
      }
      return online;
    } catch (_) {
      markOffline();
      return false;
    }
  }
}
