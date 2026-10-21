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
import 'data/repositories/chat_repository.dart';
import 'data/repositories/misc_repositories.dart';
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
import 'state/wishlist_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await LocalStore.init();
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

  final session = SessionProvider(AuthService(FirebaseAuth.instance), users, PushService(users));
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
        ChangeNotifierProvider.value(value: session),
        ChangeNotifierProvider.value(value: cart),
        ChangeNotifierProvider.value(value: wishlist),
        ChangeNotifierProvider(create: (_) => SearchHistory()),
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
      home: const SplashScreen(),
    );
  }
}
