import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/order_provider.dart';
import 'providers/product_provider.dart';
import 'screens/splash_screen.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..load()),
        ChangeNotifierProvider(create: (_) => ProductProvider()..load()),
        ChangeNotifierProvider(create: (_) => CartProvider()..load()),
        ChangeNotifierProvider(create: (_) => OrderProvider()..load()),
        ChangeNotifierProvider(create: (_) => ChatProvider()..load()),
      ],
      child: const JDMartApp(),
    ),
  );
}

class JDMartApp extends StatelessWidget {
  const JDMartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JDMart',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const SplashScreen(),
    );
  }
}
