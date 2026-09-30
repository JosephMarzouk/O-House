import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../models/club_zone.dart';

// The checklist opens and submits only inside the club's zone (ClubZone).
// The check is in the app only, by design: there is no server-side geofence
// and no coordinates travel with a submission. It keeps honest staff from
// filling a round from home; it is not proof against a determined cheat.

/// Pure, unit-tested. No zone means no rule, so everywhere is inside. A
/// mocked position (a fake-GPS app, Android's developer options) is never
/// inside: it is exactly the thing this check is meant to catch.
bool insideClub(
  ClubZone? zone,
  double lat,
  double lng, {
  bool isMocked = false,
}) {
  if (zone == null) return true;
  if (isMocked) return false;
  return Geolocator.distanceBetween(zone.lat, zone.lng, lat, lng) <=
      zone.radiusM;
}

enum ZoneState {
  inside,
  outside,
  mocked,
  denied,
  deniedForever,
  serviceOff,
  unavailable,

  /// Not a look at the phone: the club's zone has not reached this phone yet
  /// (ZoneUnknown), so there is nothing to check against.
  unknown,
}

/// The location prompt, asked up front: Home calls this once the club turns
/// out to have a zone, so the question comes at sign-in rather than halfway
/// into a round. Asks only while Android/iOS still let it (denied, not
/// deniedForever), once per call; returns what the person chose. A refusal
/// is the gate's to explain later.
Future<LocationPermission> ensureLocationPermission() async {
  final permission = await Geolocator.checkPermission();
  return permission == LocationPermission.denied
      ? Geolocator.requestPermission()
      : permission;
}

/// One look at where the phone is. [metres] is the distance to the club's
/// centre, set only when [state] is outside.
typedef ZoneCheck = ({ZoneState state, int metres});

/// Asks for the permission when it can still be asked, then one fresh fix.
/// Never throws: a failure is [ZoneState.unavailable] and the screen offers
/// Retry.
///
/// Approximate location (Android 12+ and iOS 14+ let the user pick it) counts
/// as denied: its error runs to kilometres, so staff standing in the club
/// would be told they are outside it.
Future<ZoneCheck> checkClubZone(ClubZone zone) async {
  ZoneCheck only(ZoneState s) => (state: s, metres: 0);
  try {
    final permission = await ensureLocationPermission();
    if (permission == LocationPermission.deniedForever) {
      return only(ZoneState.deniedForever);
    }
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      return only(ZoneState.denied);
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      return only(ZoneState.serviceOff);
    }
    if (await Geolocator.getLocationAccuracy() ==
        LocationAccuracyStatus.reduced) {
      return only(ZoneState.deniedForever);
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
    if (insideClub(zone, pos.latitude, pos.longitude, isMocked: pos.isMocked)) {
      return only(ZoneState.inside);
    }
    if (pos.isMocked) return only(ZoneState.mocked);
    final metres = Geolocator.distanceBetween(
      zone.lat,
      zone.lng,
      pos.latitude,
      pos.longitude,
    );
    return (state: ZoneState.outside, metres: metres.round());
  } on LocationServiceDisabledException {
    return only(ZoneState.serviceOff);
  } catch (e) {
    // A timeout indoors, mostly. No last-known fallback: a stale fix from
    // the club would let a round be filled from anywhere.
    debugPrint('[zone] no fix: $e');
    return only(ZoneState.unavailable);
  }
}
