import 'package:flutter_test/flutter_test.dart';
import 'package:o_house/features/assignments/club_zone.dart';
import 'package:o_house/models/club_zone.dart';

void main() {
  // Tahrir Square, 200 m.
  const zone = ClubZone(lat: 30.0444, lng: 31.2357, radiusM: 200);

  test('inside the radius', () {
    expect(insideClub(zone, 30.0444, 31.2357), isTrue);
    // ~111 m north.
    expect(insideClub(zone, 30.0454, 31.2357), isTrue);
  });

  test('outside the radius', () {
    // ~333 m north.
    expect(insideClub(zone, 30.0474, 31.2357), isFalse);
    expect(insideClub(zone, 0, 0), isFalse);
  });

  test('a mocked position is never inside, even at the centre', () {
    expect(insideClub(zone, 30.0444, 31.2357, isMocked: true), isFalse);
  });

  test('no zone set: no rule, so everywhere is inside', () {
    expect(insideClub(null, 0, 0), isTrue);
    expect(insideClub(null, 0, 0, isMocked: true), isTrue);
  });

  test('the zone reads the shape GET /me sends', () {
    final z = ClubZone.fromJson({'lat': 30.0444, 'lng': 31, 'radiusM': 200});
    expect([z.lat, z.lng, z.radiusM], [30.0444, 31.0, 200.0]);
  });

  // Fail closed: "no zone cached" is not "the club has no zone" until a
  // GET /me has said so.
  group('clubZoneState', () {
    const json = '{"lat": 30.0444, "lng": 31.2357, "radiusM": 200}';
    const synced = '2026-09-30T13:07:00.000';

    test('never synced, nothing cached: unknown, so the checklist is blocked', () {
      expect(clubZoneState(null, null), isA<ZoneUnknown>());
    });

    test('synced and no zone: none, so no gate', () {
      expect(clubZoneState(null, synced), isA<NoZone>());
    });

    test('a cached zone is the zone, synced or from an older build', () {
      for (final s in [synced, null]) {
        final state = clubZoneState(json, s);
        expect(state, isA<HasZone>());
        expect((state as HasZone).zone.radiusM, 200);
      }
    });
  });
}
