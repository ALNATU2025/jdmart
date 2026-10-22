import 'dart:async';
import 'dart:ui' show PlatformDispatcher;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/admin_repository.dart';
import 'data/repositories/chat_repository.dart';
import 'data/repositories/delivery_repository.dart';
import 'data/repositories/job_repository.dart';
import 'data/repositories/misc_repositories.dart';
import 'data/repositories/notification_repository.dart';
import 'data/repositories/order_repository.dart';
import 'data/repositories/product_repository.dart';
import 'data/repositories/user_repository.dart';
import 'data/services/auth_service.dart';
import 'data/services/local_store.dart';
import 'data/services/push_service.dart';
import 'features/onboarding/splash_screen.dart';
import 'firebase_options.dart';
import 'state/cart_provider.dart';
import 'state/search_history.dart';
import 'state/session_provider.dart';
import 'state/theme_controller.dart';
import 'state/wishlist_provider.dart';

/// Last start-up / runtime errors, shown on screen so problems can be reported.
final startupErrors = ValueNotifier<List<String>>([]);

void _recordError(Object e, StackTrace? st) {
  debugPrint('JDMART ERROR: $e\n$st');
  final lines = '$e\n${st ?? ''}'.split('\n').take(8).join('\n');
  startupErrors.value = [...startupErrors.value, lines].take(5).toList();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (d) {
    FlutterError.presentError(d);
    _recordError(d.exception, d.stack);
  };
  PlatformDispatcher.instance.onError = (e, st) {
    _recordError(e, st);
    return true;
  };
  ErrorWidget.builder = (d) => Material(
        color: const Color(0xFFFFF0E5),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text('Something went wrong here:\n${d.exception}',
              style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12)),
        ),
      );
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform).timeout(const Duration(seconds: 25));
    await LocalStore.init().timeout(const Duration(seconds: 10));
  } catch (e, st) {
    _recordError(e, st);
    runApp(_StartupErrorApp(error: '$e'));
    return;
  }
  await _start();
}

Future<void> _start() async {
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  final db = FirebaseFirestore.instance;
  final functions = FirebaseFunctions.instanceFor(region: AppConfig.functionsRegion);

  final users = UserRepository(db, functions);
  final products = ProductRepository(db);
  final orders = OrderRepository(db, functions);
  final chats = ChatRepository(db);
  final wishlistRepo = WishlistRepository(db);
  final banners = BannerRepository(db);
  final media = MediaRepository(FirebaseStorage.instance);
  final jobs = JobRepository(db, FirebaseStorage.instance);
  final admin = AdminRepository(db, functions, FirebaseStorage.instance);
  final deliveries = DeliveryRepository(db, functions);
  final notifications = NotificationRepository(db);

  final session = SessionProvider(AuthService(FirebaseAuth.instance, functions), users, PushService(users));
  final cart = CartProvider(products);
  final wishlist = WishlistProvider(wishlistRepo);

  // Cart and saved items follow whoever is signed in.
  void bindUser() {
    final uid = session.isLoggedIn ? session.uid : null;
    cart.bindUser(uid);
    wishlist.bindUser(uid);
  }

  session.addListener(bindUser);
  bindUser();

  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: users),
        Provider.value(value: products),
        Provider.value(value: orders),
        Provider.value(value: chats),
        Provider.value(value: banners),
        Provider.value(value: media),
        Provider.value(value: jobs),
        Provider.value(value: admin),
        Provider.value(value: deliveries),
        Provider.value(value: notifications),
        ChangeNotifierProvider.value(value: session),
        ChangeNotifierProvider.value(value: cart),
        ChangeNotifierProvider.value(value: wishlist),
        ChangeNotifierProvider(create: (_) => SearchHistory()),
        ChangeNotifierProvider(create: (_) => ThemeController()),
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
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: context.watch<ThemeController>().mode,
      themeAnimationDuration: const Duration(milliseconds: 350),
      themeAnimationCurve: Curves.easeOutCubic,
      home: const SplashScreen(),
      // Shows unexpected errors at the bottom of the screen (tap to hide), so testers can report them.
      builder: (context, child) => Stack(
        children: [
          if (child != null) child,
          ValueListenableBuilder<List<String>>(
            valueListenable: startupErrors,
            builder: (_, errors, __) => errors.isEmpty
                ? const SizedBox.shrink()
                : Positioned(
                    left: 8,
                    right: 8,
                    bottom: 8,
                    child: SafeArea(
                      child: GestureDetector(
                        onTap: () => startupErrors.value = [],
                        child: Material(
                          color: const Color(0xEEDC2626),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Text('Error (tap to hide): ${errors.last}',
                                maxLines: 6,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 11)),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Shown instead of a frozen logo when the app can't start.
class _StartupErrorApp extends StatelessWidget {
  final String error;
  const _StartupErrorApp({required this.error});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wifi_off_rounded, size: 56, color: Color(0xFFFB6401)),
                  const SizedBox(height: 16),
                  const Text("JDMart couldn't start", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  const Text('Check your internet connection, then close and reopen the app.',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  SelectableText(error, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
          ),
        ),
      );
}
