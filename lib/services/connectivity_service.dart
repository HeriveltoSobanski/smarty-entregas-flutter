import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final _connectivity = Connectivity();
  final _controller = StreamController<bool>.broadcast();

  bool _online = true;
  bool get isOnline => _online;

  Stream<bool> get onStatusChange => _controller.stream;

  Future<void> init() async {
    final result = await _connectivity.checkConnectivity();
    _online = _isConnected(result);

    _connectivity.onConnectivityChanged.listen((results) {
      final nowOnline = _isConnected(results);
      if (nowOnline != _online) {
        _online = nowOnline;
        _controller.add(_online);
      }
    });
  }

  bool _isConnected(List<ConnectivityResult> results) {
    return results.any((r) => r != ConnectivityResult.none);
  }

  void dispose() {
    _controller.close();
  }
}
