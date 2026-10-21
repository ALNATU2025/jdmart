/// App-wide settings. Fill these in before publishing.
/// Nothing here is secret: API keys for payments live only in Cloud Functions.
class AppConfig {
  static const appName = 'JDMart';
  static const tagline = 'Buy Smart. Sell Faster.';

  /// Owner of the app: full admin console access, can add other admins.
  /// Must match SUPER_ADMIN_EMAIL in functions/src/admin.ts.
  static const superAdminEmail = 'alusinebarrie578@gmail.com';

  // TODO(go-live): replace with your real support channels.
  static const supportPhone = '';
  static const supportWhatsApp = '';
  static const supportEmail = '';

  // TODO(go-live): host these pages (Firebase Hosting serves /legal/*.html from
  // the hosting/ folder) and put the final URLs here. Google Play requires them.
  static const privacyPolicyUrl = '';
  static const termsUrl = '';

  /// Online payments (Orange Money, Afrimoney, cards) go through Monime.
  /// Keep false until the MONIME_* secrets are set on Cloud Functions.
  static const onlinePaymentsEnabled = false;

  /// Google Maps API key for live delivery tracking (Maps JavaScript API for
  /// web; the Android key goes in AndroidManifest.xml). Not secret, but restrict
  /// it to your app/website in the Google Cloud console. Leave empty to show
  /// tracking as a list with "Open in Google Maps" links instead of a map.
  static const googleMapsApiKey = 'AIzaSyDvGbRhp8m-TNRMOqB3OECW6Y_cGLWxRqw';

  /// Cloud Functions region. Must match `region` in functions/src/index.ts.
  static const functionsRegion = 'europe-west1';

  static const maxListingPhotos = 6;
  static const pageSize = 20;
}
