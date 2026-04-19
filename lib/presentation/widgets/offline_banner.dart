import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/connectivity_service.dart';

class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner>
    with SingleTickerProviderStateMixin {
  bool _offline = false;
  late final AnimationController _anim;
  late final Animation<double> _slide;
  StreamSubscription<bool>? _sub;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slide = CurvedAnimation(parent: _anim, curve: Curves.easeOut);

    _offline = !ConnectivityService.instance.isOnline;
    if (_offline) _anim.value = 1.0;

    _sub = ConnectivityService.instance.onStatusChange.listen((online) {
      if (!mounted) return;
      setState(() => _offline = !online);
      if (_offline) {
        _anim.forward();
      } else {
        _anim.reverse();
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _slide,
      axisAlignment: -1,
      child: Container(
        width: double.infinity,
        color: const Color(0xFF323232),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: const Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Sem internet — exibindo dados salvos',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
