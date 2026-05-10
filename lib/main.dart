import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'services/push_notification_service.dart';
import 'services/connectivity_service.dart';
import 'package:provider/provider.dart';
import 'core/cart/cart.dart';
import 'presentation/navigation/app_routes.dart';
import 'presentation/navigation/app_pages.dart';
import 'core/utils/app_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  try {
    await PushNotificationService.init();
  } catch (e, st) { AppLogger.e('main', e, st); }
  await ConnectivityService.instance.init();
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
