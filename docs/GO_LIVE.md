# JDMart — Go-Live Guide

This guide takes JDMart from source code to a live app on Google Play, with a real backend.
Follow the steps in order. Expect about one day of setup work, plus waiting time for Google Play review
and for your Monime business account approval.

---

## Recommended backend: Firebase + Monime

| Need | Service | Why |
|---|---|---|
| Sign in | **Firebase Authentication** (phone number + SMS code) | Everyone in Sierra Leone has a phone number; no passwords to forget or leak. |
| Database | **Cloud Firestore** | Real-time updates (chat, order status), works offline on patchy networks, scales automatically. |
| Photos | **Firebase Storage** | Listing photos and avatars, protected by upload rules. |
| Server logic | **Cloud Functions** (`functions/`) | Places orders and checks stock and prices on the server, confirms payments, sends notifications. Nothing important is trusted to the phone. |
| Notifications | **Firebase Cloud Messaging** | New order, order shipped, new chat message. |
| Payments | **Monime** (monime.io) | A Sierra Leone payment platform: **Orange Money, Afrimoney and cards** through one checkout page, in Leones (SLE). |
| Web pages | **Firebase Hosting** (`hosting/`) | Payment return pages, Terms and Privacy Policy. |

Why Firebase rather than building your own server: it has first-class Flutter support (FlutterFire),
offline sync for weak 3G/4G, nothing to patch or keep running, and a free tier large enough to launch on.
You only start paying once there is real traffic.

**Costs.** Cloud Functions and scheduled jobs require the **Blaze (pay-as-you-go)** plan. A card is
needed, but a small marketplace usually stays within the free monthly allowance. Phone sign-in SMS
messages are charged per message after a small free quota, so check current prices in the Firebase
console. Set a **budget alert** (Google Cloud console → Billing → Budgets) on day one.

---

## 1. Install the tools (on your computer)

- Flutter SDK (stable): https://docs.flutter.dev/get-started/install
- Node.js 22: https://nodejs.org
- Firebase CLI: `npm install -g firebase-tools`, then `firebase login`
- FlutterFire CLI: `dart pub global activate flutterfire_cli`

## 2. Create the Firebase project

1. Go to https://console.firebase.google.com → **Add project** → name it e.g. `jdmart-sl`.
2. **Build → Firestore Database → Create database** in **production mode**. For the location, choose
   **`europe-west1` (Belgium)**, the region used by the functions. The location can't be changed later.
3. **Build → Authentication → Get started → Sign-in method → Phone → Enable.**
4. **Build → Storage → Get started** (production mode).
5. Upgrade to the **Blaze plan** (bottom-left gear → Usage and billing).
6. In the project folder:
   ```bash
   bash setup.sh            # creates the android/ and ios/ folders (Windows: run the commands inside it by hand)
   flutterfire configure    # pick your project; tick Android and iOS. This writes lib/firebase_options.dart
   cp .firebaserc.example .firebaserc   # then put your project id in it
   ```
7. **Android phone sign-in needs your app's SHA fingerprints.** Run `cd android && ./gradlew signingReport`,
   then copy the SHA-1 and SHA-256 into Firebase console → Project settings → Your apps → Android → Add fingerprint.
   Do this again later with your **release/Play signing** key (Play Console → App integrity).

## 3. Deploy the backend

```bash
cd functions && npm install && cd ..

# Payment secrets. Until your Monime account is approved, set both to "none".
firebase functions:secrets:set MONIME_ACCESS_TOKEN
firebase functions:secrets:set MONIME_SPACE_ID

firebase deploy --only firestore,storage,functions,hosting
```

This deploys the security rules, database indexes, server functions, and the web pages
(`https://<project-id>.web.app/legal/privacy.html` and `/legal/terms.html`).
Indexes take a few minutes to build. Until they finish, some lists may show "Couldn't load this".

## 4. Fill in the app settings

Edit `lib/core/config/app_config.dart`:

- `supportPhone`, `supportWhatsApp`, `supportEmail`: your real support contacts.
- `privacyPolicyUrl` and `termsUrl`: the hosting URLs from step 3. **Edit `hosting/legal/*.html` first.**
  They are templates with `[bracketed]` placeholders, and should be reviewed by a lawyer.
- `onlinePaymentsEnabled`: leave `false` until step 5 is done. Until then, buyers can only pay **Cash on Delivery**.

## 5. Turn on mobile money and card payments (Monime)

1. Create a business account at https://monime.io and complete verification (KYC).
2. In the Monime dashboard, create an **access token** and copy your **Space ID** (starts with `spc-`).
   Test in Monime's **sandbox** first.
3. Store them as secrets and redeploy:
   ```bash
   firebase functions:secrets:set MONIME_ACCESS_TOKEN   # paste the token
   firebase functions:secrets:set MONIME_SPACE_ID       # paste spc-...
   firebase deploy --only functions
   ```
4. In the Monime dashboard, add a **webhook** pointing to the `monimeWebhook` function URL
   (shown after deploy, like `https://europe-west1-<project-id>.cloudfunctions.net/monimeWebhook`).
5. Set `onlinePaymentsEnabled = true` in `app_config.dart` and release a new app version.

How payment works: the server reserves stock and creates a Monime checkout page. The buyer pays with
Orange Money, Afrimoney or card. JDMart then **asks Monime's API directly** whether the payment
completed; it never trusts the phone. Orders not paid within 30 minutes are cancelled automatically
and their stock is released.

**Refunds and seller payouts are manual in this version.** Orders cancelled after payment are marked
"refund due" and need a refund from the Monime dashboard. Seller payouts (and any commission you take)
must be handled from Monime as well. Agree these terms with your sellers before launch.

## 6. Create the first content (no mock data ships with the app)

- **Banners** (optional): in Firestore, add documents to a `banners` collection with the fields
  `title` (string), `subtitle` (string), `categoryId` (e.g. `phones`), `active` (true), `order` (number),
  and optionally `imageUrl`. The home carousel is hidden when there are none.
- **Featured listings:** set `featured: true` on a product document in the console.
- **Verified sellers:** set `verified: true` on `users/{uid}`. The badge is copied onto their listings automatically.
- **Reports:** reported listings appear in the `reports` collection. Hide a bad listing by setting its `status` to `hidden`.
- Before opening to the public, recruit a few real sellers to post listings, so the first buyers find products.

## 7. Test before publishing (with real phones)

- [ ] Sign up with a phone number, then sign out and sign back in
- [ ] Post a listing with photos, edit it, mark it sold, relist it
- [ ] On a second phone: search, save, chat with the seller, add to cart
- [ ] Cash-on-delivery order: the seller gets a notification, then confirms → ships → delivers; the buyer can then review
- [ ] Buyer cancels a pending order: the stock comes back
- [ ] (After Monime) online payment in sandbox: order becomes **paid** and **confirmed**; abandon a payment and check that it expires after 30 minutes
- [ ] Delete a test account from Account → Delete my account

## 8. Publish on Google Play

1. Create a Google Play developer account (one-time fee) at https://play.google.com/console.
2. Create an upload key and configure signing: https://docs.flutter.dev/deployment/android
3. Build: `flutter build appbundle --release`, then upload `build/app/outputs/bundle/release/app-release.aab`.
4. Complete **Data safety** (phone number, name, photos, messages, purchase history; data encrypted in
   transit; account deletion available in the app) and add the **Privacy Policy URL**.
5. Add the Play signing SHA-1/SHA-256 to Firebase (step 2.7), or phone sign-in will fail in the store build.
6. Start with **Internal testing**, then **Closed testing**, then **Production**.

## After launch: what to add next

- **Better search**: when you have thousands of listings, add the Algolia or Typesense Firebase extension.
- **App Check**: enable Firebase App Check (Play Integrity) to block fake clients, then set `enforceAppCheck: true` in `functions/src/orders.ts`.
- **Admin dashboard**: a small web app for verifying sellers, handling reports and refunds.
- **Automatic seller payouts** through Monime's payouts API.
- **Crash reporting** with Firebase Crashlytics.

---

### Where things are in the code

```
lib/
  core/            config (app_config.dart), catalog (categories, towns, delivery fees), theme, formatters
  data/models/     Firestore document shapes (Product, Order, Conversation, ...)
  data/repositories/  the only code that talks to Firebase
  data/services/   phone sign-in, push notifications, on-device storage
  state/           session, cart, saved items, search history
  features/        screens by area: auth, home, catalog, cart, checkout, orders, chat, account, sell
  shared/widgets/  reusable UI pieces
functions/src/     Cloud Functions: orders.ts, monime.ts, triggers.ts, account.ts
firestore.rules    who can read or write what
storage.rules      photo upload rules
hosting/           payment return pages + legal page templates
```
