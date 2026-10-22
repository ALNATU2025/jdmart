import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/delivery.dart';
import '../../data/repositories/delivery_repository.dart';
import '../../data/services/location_service.dart';
import '../../shared/maps/maps_loader.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/contact_actions.dart';
import '../../shared/widgets/motion.dart';
import '../../state/session_provider.dart';
import 'rider_widgets.dart';

/// Freetown, when nobody is sharing a location yet.
const _freetown = LatLng(8.4844, -13.2344);

const _roles = ['seller', 'rider', 'buyer'];

String _roleLabel(String role) => switch (role) {
      'rider' => 'Rider',
      'seller' => 'Seller (pickup)',
      'buyer' => 'Buyer (drop-off)',
      _ => role,
    };

Color _roleColor(String role) => switch (role) {
      'rider' => AppColors.orange,
      'seller' => AppColors.blue,
      _ => AppColors.success,
    };

IconData _roleIcon(String role) => switch (role) {
      'rider' => Icons.delivery_dining_rounded,
      'seller' => Icons.storefront_rounded,
      _ => Icons.home_rounded,
    };

double _hue(String role) => switch (role) {
      'rider' => BitmapDescriptor.hueOrange,
      'seller' => BitmapDescriptor.hueAzure,
      _ => BitmapDescriptor.hueGreen,
    };

/// Live map where the buyer, the seller and the rider see each other.
class LiveTrackingScreen extends StatefulWidget {
  final String orderId;
  const LiveTrackingScreen({super.key, required this.orderId});

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  late final DeliveryRepository _repo = context.read<DeliveryRepository>();
  StreamSubscription<Position>? _sub;
  DateTime _lastSent = DateTime.fromMillisecondsSinceEpoch(0);
  Position? _me;
  bool _sharing = false;
  GoogleMapController? _map;
  String _fittedFor = '';

  /// null = loading, true = map available, false = show the list fallback.
  bool? _mapsReady;
  String? _mapsError;

  @override
  void initState() {
    super.initState();
    if (AppConfig.googleMapsApiKey.isEmpty || (!kIsWeb && !AppConfig.androidMapsEnabled)) {
      _mapsReady = false;
      _mapsError = 'The live map isn\'t set up on this device yet.';
    } else {
      ensureGoogleMapsLoaded(AppConfig.googleMapsApiKey).then((_) {
        if (mounted) setState(() => _mapsReady = true);
      }).catchError((Object e) {
        if (mounted) {
          setState(() {
            _mapsReady = false;
            _mapsError = e.toString().replaceFirst('Exception: ', '');
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _map?.dispose();
    super.dispose();
  }

  Future<void> _startSharing(Delivery d, String uid, String name) async {
    final err = await LocationService.ensurePermission();
    if (!mounted) return;
    if (err != null) {
      showSnack(context, err, error: true);
      return;
    }
    final role = d.roleOf(uid);
    Future<void> send(Position p, {bool force = false}) async {
      _me = p;
      if (mounted) setState(() {});
      final now = DateTime.now();
      if (!force && now.difference(_lastSent).inSeconds < 6) return;
      _lastSent = now;
      try {
        await _repo.share(widget.orderId, uid,
            LivePoint(lat: p.latitude, lng: p.longitude, heading: p.heading, role: role, name: name, at: now));
      } catch (e) {
        debugPrint('share location failed: $e');
      }
    }

    setState(() => _sharing = true);
    final first = await LocationService.current();
    if (first != null) await send(first, force: true);
    _sub?.cancel();
    _sub = LocationService.positions().listen(send, onError: (Object e) {
      if (mounted) showSnack(context, 'Location stopped: $e', error: true);
    });
    if (mounted) showSnack(context, 'Sharing your live location with this delivery');
  }

  Future<void> _stopSharing(String uid) async {
    await _sub?.cancel();
    _sub = null;
    setState(() => _sharing = false);
    try {
      await _repo.stopSharing(widget.orderId, uid);
    } catch (_) {}
  }

  void _fit(Delivery d, {bool force = false}) {
    final map = _map;
    if (map == null) return;
    final pts = [
      for (final r in _roles)
        if (d.locationOf(r) != null) LatLng(d.locationOf(r)!.lat, d.locationOf(r)!.lng),
    ];
    final signature = pts.length.toString();
    if (!force && signature == _fittedFor) return;
    _fittedFor = signature;
    if (pts.isEmpty) return;
    if (pts.length == 1) {
      map.animateCamera(CameraUpdate.newLatLngZoom(pts.first, 15));
      return;
    }
    var s = pts.first.latitude, n = s, w = pts.first.longitude, e = w;
    for (final p in pts) {
      if (p.latitude < s) s = p.latitude;
      if (p.latitude > n) n = p.latitude;
      if (p.longitude < w) w = p.longitude;
      if (p.longitude > e) e = p.longitude;
    }
    map.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(southwest: LatLng(s - 0.002, w - 0.002), northeast: LatLng(n + 0.002, e + 0.002)),
      70,
    ));
  }

  Set<Marker> _markers(Delivery d) => {
        for (final r in _roles)
          if (d.locationOf(r) != null)
            Marker(
              markerId: MarkerId(r),
              position: LatLng(d.locationOf(r)!.lat, d.locationOf(r)!.lng),
              icon: BitmapDescriptor.defaultMarkerWithHue(_hue(r)),
              infoWindow: InfoWindow(
                title: '${_roleLabel(r)}: ${d.locationOf(r)!.name}',
                snippet: 'Updated ${Fmt.ago(d.locationOf(r)!.at)}',
              ),
            ),
      };

  Set<Polyline> _route(Delivery d) {
    final rider = d.locationOf('rider');
    final target = d.status == DeliveryStatus.assigned ? d.locationOf('seller') : d.locationOf('buyer');
    if (rider == null || target == null || d.status == DeliveryStatus.delivered) return {};
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: [LatLng(rider.lat, rider.lng), LatLng(target.lat, target.lng)],
        color: AppColors.orange,
        width: 4,
        patterns: [PatternItem.dash(18), PatternItem.gap(10)],
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final uid = session.uid;
    return StreamView<Delivery?>(
      id: widget.orderId,
      create: () => _repo.watch(widget.orderId),
      loading: const Scaffold(body: LoadingView()),
      builder: (context, d) {
        if (d == null || uid == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(
              icon: Icons.location_off_outlined,
              title: 'Tracking not available',
              message: 'Open tracking from the order page to get a delivery code.',
            ),
          );
        }
        WidgetsBinding.instance.addPostFrameCallback((_) => _fit(d));
        return Scaffold(
          body: Stack(
            children: [
              Positioned.fill(child: _mapArea(d)),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      _roundButton(Icons.arrow_back_rounded, () => Navigator.maybePop(context), 'Back'),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FadeSlideIn(
                          offset: const Offset(0, -0.3),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: context.surface,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: softShadow(2),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.local_shipping_rounded, color: AppColors.orange, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text('Order #${d.shortOrderId} • ${d.code}',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (_mapsReady == true) ...[
                        const SizedBox(width: 10),
                        _roundButton(Icons.center_focus_strong_rounded, () => _fit(d, force: true), 'Show everyone'),
                      ],
                    ],
                  ),
                ),
              ),
              DraggableScrollableSheet(
                initialChildSize: _mapsReady == true ? 0.42 : 0.72,
                minChildSize: 0.18,
                maxChildSize: 0.9,
                builder: (context, scroll) => _panel(context, d, uid, session.profile?.name ?? '', scroll),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _roundButton(IconData icon, VoidCallback onTap, String tip) => Tooltip(
        message: tip,
        child: Pressable(
          onTap: onTap,
          scale: 0.9,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: context.surface, shape: BoxShape.circle, boxShadow: softShadow(2)),
            child: Icon(icon, color: context.ink),
          ),
        ),
      );

  Widget _mapArea(Delivery d) {
    if (_mapsReady == null) return Container(color: context.soft, child: const LoadingView());
    if (_mapsReady == false) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [context.blueTint, context.soft],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        alignment: const Alignment(0, -0.55),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Floating(child: Icon(Icons.map_rounded, size: 64, color: context.brand)),
              const SizedBox(height: 10),
              Text(_mapsError ?? 'Map unavailable',
                  textAlign: TextAlign.center, style: TextStyle(color: context.muted, fontSize: 13)),
              const SizedBox(height: 4),
              Text('You can still open each location in Google Maps below.',
                  textAlign: TextAlign.center, style: TextStyle(color: context.muted, fontSize: 12)),
            ],
          ),
        ),
      );
    }
    return GoogleMap(
      initialCameraPosition: const CameraPosition(target: _freetown, zoom: 12),
      markers: _markers(d),
      polylines: _route(d),
      zoomControlsEnabled: false,
      myLocationButtonEnabled: false,
      mapToolbarEnabled: false,
      style: context.isDark ? _darkMapStyle : null,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).size.height * 0.35, top: 70),
      onMapCreated: (c) {
        _map = c;
        _fittedFor = '';
        _fit(d);
      },
    );
  }

  Widget _panel(BuildContext context, Delivery d, String uid, String myName, ScrollController scroll) {
    final role = d.roleOf(uid);
    return Container(
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 24)],
      ),
      child: ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
        children: [
          Center(
            child: Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(color: context.line, borderRadius: BorderRadius.circular(5)),
            ),
          ),
          const SizedBox(height: 14),
          _StatusSteps(status: d.status),
          const SizedBox(height: 16),
          if (role == 'buyer') _BuyerPin(orderId: d.orderId, delivered: d.status == DeliveryStatus.delivered),
          if (role == 'seller' && d.riderId == null) _CodeShare(code: d.code),
          for (final r in _roles) _person(d, r, uid),
          const SizedBox(height: 6),
          if (d.status != DeliveryStatus.delivered)
            Container(
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(color: context.soft, borderRadius: BorderRadius.circular(16)),
              child: SwitchListTile(
                value: _sharing,
                activeThumbColor: AppColors.success,
                onChanged: (v) => v ? _startSharing(d, uid, myName) : _stopSharing(uid),
                secondary: Icon(_sharing ? Icons.my_location_rounded : Icons.location_searching_rounded,
                    color: _sharing ? AppColors.success : context.muted),
                title: const Text('Share my live location', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  _sharing
                      ? 'Visible to the buyer, seller and rider of this order. Keep this screen open.'
                      : 'Only people on this delivery can see it.',
                  style: TextStyle(fontSize: 12, color: context.muted),
                ),
              ),
            ),
          if (role == 'rider') ...[
            const SizedBox(height: 14),
            _riderActions(d, uid, myName),
          ],
        ],
      ),
    );
  }

  Widget _person(Delivery d, String r, String uid) {
    final name = switch (r) {
      'rider' => d.riderName,
      'seller' => d.sellerName,
      _ => d.buyerName,
    };
    final phone = switch (r) {
      'rider' => d.riderPhone,
      'seller' => d.sellerPhone,
      _ => d.buyerPhone,
    };
    final loc = d.locationOf(r);
    final isMe = d.uidFor(r) == uid;
    final me = _me;
    String where;
    if (loc == null) {
      where = r == 'buyer' && d.dropoff.isNotEmpty ? d.dropoff : 'Location not shared';
    } else {
      where = loc.isStale ? 'Last seen ${Fmt.ago(loc.at)}' : 'Live now';
      if (me != null && !isMe) {
        where += ' • ${LocationService.formatDistance(LocationService.distance(me.latitude, me.longitude, loc.lat, loc.lng))} away';
      }
    }
    final color = _roleColor(r);
    return FadeSlideIn(
      key: ValueKey('$r-${name ?? ''}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    if (r == 'rider' && d.riderId != null)
                      RiderAvatar(name: name ?? '', photoUrl: d.riderPhotoUrl, radius: 22)
                    else
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: color.withValues(alpha: 0.15),
                        child: Icon(_roleIcon(r), color: color),
                      ),
                    if (loc != null && !loc.isStale) const Positioned(right: -1, bottom: -1, child: _LiveDot()),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${_roleLabel(r)}${isMe ? ' • you' : ''}',
                          style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w700)),
                      Text(name ?? (r == 'rider' ? 'No rider yet' : '—'),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      if (r == 'rider' && d.riderVehicleLabel.isNotEmpty)
                        Text('Verified rider • ${d.riderVehicleLabel}',
                            style: TextStyle(color: context.brand, fontSize: 12, fontWeight: FontWeight.w600)),
                      Text(where,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: context.muted, fontSize: 12)),
                    ],
                  ),
                ),
                if (loc != null && !isMe)
                  IconButton(
                    tooltip: 'Directions in Google Maps',
                    onPressed: () => openExternal(
                        'https://www.google.com/maps/dir/?api=1&destination=${loc.lat},${loc.lng}&travelmode=driving'),
                    icon: Icon(Icons.directions_rounded, color: context.brand),
                  ),
              ],
            ),
            if (!isMe && (phone ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              ContactActions(
                phone: phone,
                whatsAppText: 'Hello, about JDMart delivery ${d.code}.',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _riderActions(Delivery d, String uid, String myName) {
    switch (d.status) {
      case DeliveryStatus.assigned:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange),
              onPressed: () async {
                final err = await runWithProgress(context, () => _repo.pickup(d.orderId));
                if (!mounted) return;
                if (err != null) {
                  showSnack(context, err, error: true);
                  return;
                }
                showSnack(context, 'Picked up — the buyer can now follow you live');
                if (!_sharing) await _startSharing(d, uid, myName);
              },
              icon: const Icon(Icons.inventory_2_rounded),
              label: const Text("I've picked up the package"),
            ),
            TextButton(
              onPressed: () async {
                final ok = await confirmDialog(context,
                    title: 'Release this delivery?',
                    message: 'The seller will need another rider.',
                    confirm: 'Release',
                    danger: true);
                if (!ok || !mounted) return;
                await _stopSharing(uid);
                if (!mounted) return;
                final err = await runWithProgress(context, () => _repo.release(d.orderId));
                if (!mounted) return;
                if (err != null) {
                  showSnack(context, err, error: true);
                } else {
                  Navigator.pop(context);
                }
              },
              child: const Text('Release job', style: TextStyle(color: AppColors.danger)),
            ),
          ],
        );
      case DeliveryStatus.pickedUp:
        return ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
          onPressed: () => _deliver(d, uid),
          icon: const Icon(Icons.verified_rounded),
          label: const Text('Mark as delivered'),
        );
      case DeliveryStatus.delivered:
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            children: [
              Icon(Icons.celebration_rounded, color: AppColors.success),
              SizedBox(width: 10),
              Expanded(child: Text('Delivered. Great job! 🎉', style: TextStyle(fontWeight: FontWeight.w700))),
            ],
          ),
        );
      case DeliveryStatus.waiting:
        return const SizedBox.shrink();
    }
  }

  Future<void> _deliver(Delivery d, String uid) async {
    final pinCtrl = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Buyer handover PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Ask ${d.buyerName.isEmpty ? 'the buyer' : d.buyerName} for the 4-digit PIN shown in their app.',
                style: TextStyle(color: ctx.muted)),
            const SizedBox(height: 14),
            TextField(
              controller: pinCtrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              textAlign: TextAlign.center,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 28, letterSpacing: 12, fontWeight: FontWeight.w800),
              decoration: const InputDecoration(counterText: '', hintText: '••••'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, pinCtrl.text.trim()), child: const Text('Confirm')),
        ],
      ),
    );
    pinCtrl.dispose();
    if (pin == null || pin.length != 4 || !mounted) return;
    final err = await runWithProgress(context, () => _repo.deliver(d.orderId, pin));
    if (!mounted) return;
    if (err != null) {
      showSnack(context, err, error: true);
      return;
    }
    HapticFeedback.heavyImpact();
    await _stopSharing(uid);
    if (mounted) showSnack(context, 'Delivered ✅ Order completed');
  }
}

/// Four-step progress: waiting → assigned → picked up → delivered.
class _StatusSteps extends StatelessWidget {
  final DeliveryStatus status;
  const _StatusSteps({required this.status});

  @override
  Widget build(BuildContext context) {
    const steps = [
      (Icons.hourglass_top_rounded, 'Waiting'),
      (Icons.delivery_dining_rounded, 'Rider assigned'),
      (Icons.inventory_2_rounded, 'Picked up'),
      (Icons.verified_rounded, 'Delivered'),
    ];
    final current = status.index;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSwitcher(
          duration: Motion.medium,
          child: Text(status.label,
              key: ValueKey(status), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (var i = 0; i < steps.length; i++) ...[
              AnimatedContainer(
                duration: Motion.slow,
                curve: Motion.curve,
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: i <= current ? AppColors.orangeGradient : null,
                  color: i <= current ? null : context.soft,
                ),
                child: Icon(steps[i].$1, size: 18, color: i <= current ? Colors.white : context.muted),
              ),
              if (i < steps.length - 1)
                Expanded(
                  child: Container(
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(color: context.soft, borderRadius: BorderRadius.circular(4)),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AnimatedFractionallySizedBox(
                        duration: Motion.slow,
                        curve: Motion.curve,
                        widthFactor: i < current ? 1 : 0,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: AppColors.orangeGradient,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var i = 0; i < steps.length; i++)
              Expanded(
                child: Text(steps[i].$2,
                    textAlign: i == 0
                        ? TextAlign.left
                        : i == steps.length - 1
                            ? TextAlign.right
                            : TextAlign.center,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: i <= current ? context.ink : context.muted,
                      fontWeight: i == current ? FontWeight.w700 : FontWeight.w500,
                    )),
              ),
          ],
        ),
      ],
    );
  }
}

/// Pulsing green dot = sharing live right now.
class _LiveDot extends StatefulWidget {
  const _LiveDot();

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: AppColors.success,
            shape: BoxShape.circle,
            border: Border.all(color: context.surface, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.success.withValues(alpha: 0.5 * (1 - _c.value)),
                blurRadius: 0,
                spreadRadius: 8 * _c.value,
              ),
            ],
          ),
        ),
      );
}

/// The buyer's handover PIN, shown big.
class _BuyerPin extends StatelessWidget {
  final String orderId;
  final bool delivered;
  const _BuyerPin({required this.orderId, required this.delivered});

  @override
  Widget build(BuildContext context) {
    if (delivered) return const SizedBox.shrink();
    return FutureBuilder<String?>(
      future: context.read<DeliveryRepository>().pin(orderId),
      builder: (context, snap) {
        final pin = snap.data;
        if (pin == null) return const SizedBox.shrink();
        return FadeSlideIn(
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                const Icon(Icons.lock_rounded, color: Colors.white),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Handover PIN\nGive it to the rider only when you have your items.',
                      style: TextStyle(color: Colors.white, fontSize: 12.5, height: 1.35)),
                ),
                Text(pin,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 6)),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Seller: copy or send the code to a rider.
class _CodeShare extends StatelessWidget {
  final String code;
  const _CodeShare({required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: context.orangeTint, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Send this code to your dispatch rider', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('They open JDMart → Account → Deliveries & tracking and enter it to accept the job.',
              style: TextStyle(color: context.muted, fontSize: 12)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(code, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 2)),
              ),
              IconButton(
                tooltip: 'Copy',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  showSnack(context, 'Code copied');
                },
                icon: const Icon(Icons.copy_rounded),
              ),
              IconButton(
                tooltip: 'Send on WhatsApp',
                onPressed: () => openExternal('https://wa.me/?text=${Uri.encodeComponent(
                    'JDMart delivery job. Open JDMart > Account > Deliveries & tracking and enter code $code')}'),
                icon: const Icon(Icons.send_rounded, color: Color(0xFF25D366)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

const _darkMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#1d2840"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#98a2b7"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#0b1220"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#2a3652"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#3b4a6b"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#0b1220"}]},
  {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#18233a"}]}
]
''';
