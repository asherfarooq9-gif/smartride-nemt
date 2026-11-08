/// The relay servers one person's phone uses for an internet call.
class IceServers {
  const IceServers({required this.servers, required this.ttl});

  /// In the shape the WebRTC library takes: `urls`, and for a relay
  /// `username` and `credential`. Empty when the server has no relay set up.
  final List<Map<String, dynamic>> servers;

  /// How long the relay login stays valid.
  final Duration ttl;

  factory IceServers.fromJson(Map<String, dynamic> json) {
    final servers = <Map<String, dynamic>>[];
    for (final item in json['ice_servers'] as List<dynamic>? ?? const []) {
      if (item is! Map<String, dynamic>) continue;
      final urls = item['urls'];
      if (urls is! List || urls.isEmpty || urls.any((u) => u is! String)) {
        continue;
      }
      servers.add({
        'urls': List<String>.from(urls),
        if (item['username'] is String) 'username': item['username'],
        if (item['credential'] is String) 'credential': item['credential'],
      });
    }
    return IceServers(
      servers: servers,
      ttl: Duration(seconds: (json['ttl_seconds'] as num?)?.toInt() ?? 3600),
    );
  }
}
