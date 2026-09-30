import 'dart:convert';

/// Where the club is: a point and a radius, set once by an admin on the
/// portal's Club settings screen (club_location). It rides on GET /me as
/// `location` and is cached with the profile (clubZoneProvider), so the
/// checklist's zone check (features/assignments/club_zone.dart) works offline.
class ClubZone {
  const ClubZone({required this.lat, required this.lng, required this.radiusM});

  factory ClubZone.fromJson(Map<String, dynamic> j) => ClubZone(
    lat: (j['lat'] as num).toDouble(),
    lng: (j['lng'] as num).toDouble(),
    radiusM: (j['radiusM'] as num).toDouble(),
  );

  final double lat;
  final double lng;
  final double radiusM;
}

/// What this phone knows about the club's zone (clubZoneProvider). The gate
/// fails closed on [ZoneUnknown]: a phone that never reached GET /me (a dev
/// build without `adb reverse` once went a whole day like that) must not
/// read as "this club has no zone" and skip the check.
sealed class ClubZoneState {
  const ClubZoneState();
}

/// GET /me has never succeeded here, so a zone may exist: no checklist.
final class ZoneUnknown extends ClubZoneState {
  const ZoneUnknown();
}

/// GET /me said the club has no zone: no gate.
final class NoZone extends ClubZoneState {
  const NoZone();
}

final class HasZone extends ClubZoneState {
  const HasZone(this.zone);
  final ClubZone zone;
}

/// From the two cached settings: `club_location` (the zone, deleted when /me
/// says there is none) and `club_location_synced` (when /me last succeeded).
/// A zone cached without the mark is still a zone: the build before this one
/// cached the zone alone. Pure, unit-tested.
ClubZoneState clubZoneState(String? location, String? synced) {
  if (location != null) {
    return HasZone(
      ClubZone.fromJson(jsonDecode(location) as Map<String, dynamic>),
    );
  }
  return synced == null ? const ZoneUnknown() : const NoZone();
}
