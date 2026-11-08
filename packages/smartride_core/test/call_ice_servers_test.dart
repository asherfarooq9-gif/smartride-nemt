import 'package:flutter_test/flutter_test.dart';
import 'package:smartride_core/smartride_core.dart';

void main() {
  test('reads relay servers with their login', () {
    final servers = IceServers.fromJson({
      'ice_servers': [
        {
          'urls': ['stun:turn.example.com:3478'],
        },
        {
          'urls': ['turn:turn.example.com:3478?transport=udp'],
          'username': '1762600000:abc',
          'credential': 'secret',
        },
      ],
      'ttl_seconds': 3600,
    });

    expect(servers.ttl, const Duration(hours: 1));
    expect(servers.servers, [
      {
        'urls': ['stun:turn.example.com:3478'],
      },
      {
        'urls': ['turn:turn.example.com:3478?transport=udp'],
        'username': '1762600000:abc',
        'credential': 'secret',
      },
    ]);
  });

  test('an empty list means no relay is set up', () {
    final servers =
        IceServers.fromJson({'ice_servers': [], 'ttl_seconds': 3600});

    expect(servers.servers, isEmpty);
  });

  test('drops entries it cannot use instead of passing them to the call', () {
    final servers = IceServers.fromJson({
      'ice_servers': [
        {'urls': 'not-a-list'},
        {'urls': []},
        {'nothing': 1},
        {
          'urls': ['turn:ok:3478'],
          'username': 'u',
          'credential': 'c',
          'extra': 'ignored',
        },
      ],
      'ttl_seconds': 60,
    });

    expect(servers.servers, [
      {
        'urls': ['turn:ok:3478'],
        'username': 'u',
        'credential': 'c',
      },
    ]);
  });
}
