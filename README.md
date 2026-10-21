# JDMart — Buy Smart. Sell Faster.

A Sierra Leone marketplace app built with **Flutter (Dart)**. Anyone can buy, and anyone can sell, from one account.

## What's inside

**Buyers**
- Home feed with an auto-sliding promo banner, category strip, Flash Deals with a countdown, featured items, and "Just listed"
- Search with recent and trending searches, plus filters for category, city, condition and price range (in Leones), and sorting
- Product page with a photo gallery, discount badge, stock count, delivery fee to your city, seller card, reviews and similar items
- Cart with quantity limits based on stock, swipe to remove, and a running total of your savings
- Checkout with delivery address and landmark, delivery fees for 15 cities and towns, and payment by **Orange Money**, **Afrimoney (Africell)**, card, or **cash on delivery**
- Order tracking (Pending → Confirmed → On the way → Delivered), and you can cancel an order while it is still pending
- Saved items (wishlist), plus chat with sellers that has quick-reply chips

**Sellers**
- Post an item with up to 6 photos (camera or gallery), a category, condition, price and old price, quantity, location, and whether the price is negotiable
- Edit, mark as sold, relist or delete a listing
- Seller Hub showing earnings, orders to fulfil, active listings, views and low-stock alerts
- Sales orders, where you move each order through its delivery stages or decline it
- A public seller profile with a verified badge, average rating and all your listings

**Sierra Leone details**: prices in new Leones (`Le 3,850`), +232 phone numbers (you can sign in with `076 123456`), cities from Freetown to Kailahun, the "Kushe!" greeting, and safety tips about mobile money.

## Run it

You need the Flutter SDK (3.22 or newer): https://docs.flutter.dev/get-started/install

### macOS / Linux
```bash
cd jdmart
bash setup.sh      # creates the android/ios/web folders, icons, splash screen and permissions, then runs the tests
flutter run
```

### Windows (PowerShell)
```powershell
cd jdmart
flutter create --project-name jdmart --org sl.jdmart --platforms=android,ios,web .
flutter pub get
dart run flutter_launcher_icons
dart run flutter_native_splash:create
flutter run
```
On Windows, also add `<uses-permission android:name="android.permission.INTERNET"/>` inside `<manifest>` in
`android/app/src/main/AndroidManifest.xml`. Release builds need it to load fonts and online images.

To try it quickly in a browser, run `flutter run -d chrome`.

**Demo seller login:** `076 123456` / `seller123` (Kamara Electronics). You can also create your own account. Any account can buy and sell.

## Build for release
```bash
flutter build apk --release        # Android APK to share or sideload
flutter build appbundle --release  # For the Google Play Store
flutter build ipa                  # iOS (requires a Mac and Xcode)
```

## Project structure
```
lib/
  main.dart                  App entry and providers
  theme/app_theme.dart       Brand colours from the logo (#0029A8 blue, #FB6401 orange)
  models/models.dart         AppUser, Product, Review, CartItem, Order, Conversation
  data/seed_data.dart        Categories, cities and delivery fees, payment methods, demo sellers and products
  services/storage_service.dart  Persistence (shared_preferences)
  providers/                 Auth, Product, Cart, Order and Chat state (Provider)
  widgets/                   Product card and grid, product image, shared UI
  screens/                   Splash, onboarding, auth, home, search, product, cart, checkout,
                             orders, chats, account, sell/ (add product, my listings, seller hub)
assets/images/               logo.png, logo_mark.png (app icon), logo_mark_transparent.png
```

## Going live (next steps)
This version saves all data on the device, so it works fully offline and is ready to demo. To make it a shared,
nationwide marketplace, connect a backend:

1. **Backend**: Firebase (Auth, Firestore, Storage) or Supabase. Every read and write already goes through
   `StorageService` and the providers, so you only change those files. Each model already has `toJson`/`fromJson`.
2. **Phone sign-in**: Firebase Phone Auth (SMS OTP) to replace the demo password login.
3. **Payments**: connect to Orange Money and Afrimoney merchant APIs, or use an aggregator that supports Sierra Leone
   mobile money. The payment step in `OrderProvider.placeOrder` is marked as simulated.
4. **Push notifications**: Firebase Cloud Messaging for new orders and chat messages.
5. **Photos**: upload listing images to cloud storage and save the URLs. `ProductImage` already shows URLs.
