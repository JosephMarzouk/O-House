import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:o_house/data/api_client.dart';
import 'package:o_house/push/push_service.dart';

void main() {
  group('routeFor: where a tapped push opens', () {
    test('a round, the Tasks tab, Home, or nowhere', () {
      expect(routeFor({'open': 'task', 'assignmentId': 'a1'}), '/tasks/a1');
      expect(routeFor({'open': 'tasks'}), '/tasks');
      // A manager's copy names the round but opens Home: it isn't in their list.
      expect(routeFor({'open': 'home', 'assignmentId': 'a1'}), '/home');
    });

    test('anything malformed stays where the app opens', () {
      expect(routeFor({'open': 'task'}), isNull);
      expect(routeFor({'open': 'task', 'assignmentId': ''}), isNull);
      expect(routeFor({'open': 'elsewhere'}), isNull);
      expect(routeFor({}), isNull);
    });
  });

  test('the device token goes up with PUT and comes back with DELETE, encoded', () async {
    final seen = <String>[];
    final api = ApiClient(
      baseUrl: 'http://api',
      club: 'ohouse',
      token: () => 'access',
      refreshSession: () async => false,
      client: MockClient((r) async {
        seen.add('${r.method} ${r.url.path} ${r.body}');
        return http.Response('', 204);
      }),
    );
    await api.put('/me/devices', json: {'token': 'a:b/c', 'platform': 'android'});
    await api.delete('/me/devices/${Uri.encodeComponent('a:b/c')}');
    expect(seen, [
      'PUT /me/devices {"token":"a:b/c","platform":"android"}',
      'DELETE /me/devices/a%3Ab%2Fc ',
    ]);
  });
}
