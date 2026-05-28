import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
// ignore: unnecessary_import
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'services/push_notification_service.dart';
import 'services/connectivity_service.dart';
import 'package:provider/provider.dart';
import 'core/cart/cart.dart';
import 'presentation/navigation/app_routes.dart';
import 'presentation/navigation/app_pages.dart';
import 'core/utils/app_logger.dart';

// Token passado em build: --dart-define=MAPBOX_TOKEN=pk.eyJ1...
const _mapboxToken = String.fromEnvironment('MAPBOX_TOKEN');

void main() {
  runZonedGuarded(_boot, (e, st) {
    AppLogger.e('Zone', e, st);
    if (!kIsWeb) {
      try {
        FirebaseCrashlytics.instance.recordError(e, st, fatal: true);
      } catch (_) {}
    }
  });
}

Future<void> _boot() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (_mapboxToken.isNotEmpty) {
    MapboxOptions.setAccessToken(_mapboxToken);
  }
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Crashlytics não suporta web
  if (!kIsWeb) {
    FlutterError.onError = (details) {
      AppLogger.e('FlutterError', details.exception, details.stack ?? StackTrace.empty);
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    };
  } else {
    FlutterError.onError = (details) {
      AppLogger.e('FlutterError', details.exception, details.stack ?? StackTrace.empty);
    };
  }
  GoogleFonts.poppins().fontFamily;
  try {
    await PushNotificationService.init();
  } catch (e, st) { AppLogger.e('main', e, st); }
  await ConnectivityService.instance.init();
  await Cart.instance.carregar();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Verifica se o app foi aberto por toque em notificação (estado terminated)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PushNotificationService.checarMensagemInicial();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<Cart>.value(
      value: Cart.instance,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Smarty Entregas',
        theme: AppTheme.theme,
        navigatorKey: PushNotificationService.navigatorKey,
        initialRoute: AppRoutes.splash,
        routes: AppPages.routes,
      ),
    );
  }
}
