import 'dart:async';

import 'package:o_house/tenant.dart';

/// Tests run without a flavor, and the app refuses to guess its club; they
/// run as O West, the one club whose values the tests were written against.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  debugTenant = Tenant.owest;
  await testMain();
}
