import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'brand.dart';

enum NetUi { online, offline, recovered }

class NetStatusController extends StateNotifier<NetUi> {
  NetStatusController() : super(NetUi.online) {
    _init();
  }

  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 4),
    receiveTimeout: const Duration(seconds: 4),
  ));
  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _ping;
  Timer? _hide;
  bool _disposed = false;

  Future<void> _init() async {
    final first = await Connectivity().checkConnectivity();
    _apply(first);
    _sub = Connectivity().onConnectivityChanged.listen(_apply);
    _schedulePing(offline: state == NetUi.offline);
  }

  bool _isOffline(List<ConnectivityResult> list) =>
      list.isEmpty || list.every((e) => e == ConnectivityResult.none);

  void _apply(List<ConnectivityResult> list) {
    if (_disposed) return;
    if (_isOffline(list)) {
      _hide?.cancel();
      state = NetUi.offline;
      _schedulePing(offline: true);
      return;
    }
    _markOnline();
    unawaited(_pingHealth());
  }

  void _schedulePing({required bool offline}) {
    _ping?.cancel();
    _ping = Timer.periodic(
      Duration(seconds: offline ? 4 : 20),
      (_) => _pingHealth(),
    );
  }

  Future<void> _pingHealth() async {
    try {
      await _dio.get<dynamic>('${PigptBrand.apiBase}/health');
      if (!_disposed && state == NetUi.offline) _markOnline();
    } catch (_) {
      // Trust connectivity_plus for offline; ping only confirms recovery.
    }
  }

  void _markOnline() {
    if (_disposed) return;
    if (state == NetUi.offline || state == NetUi.recovered) {
      state = NetUi.recovered;
      _hide?.cancel();
      _hide = Timer(const Duration(milliseconds: 2200), () {
        if (!_disposed && state == NetUi.recovered) state = NetUi.online;
      });
    }
    _schedulePing(offline: false);
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    _ping?.cancel();
    _hide?.cancel();
    super.dispose();
  }
}

final netStatusProvider =
    StateNotifierProvider<NetStatusController, NetUi>((ref) {
  return NetStatusController();
});
