import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:patient_app/shared/map_style_cache.dart';

void main() {
  late Directory dir;
  late int networkCalls;
  var clock = DateTime(2026, 10, 30, 12);

  setUp(() {
    dir = Directory.systemTemp.createTempSync('map_style_cache_test');
    networkCalls = 0;
    clock = DateTime(2026, 10, 30, 12);
  });

  tearDown(() => dir.deleteSync(recursive: true));

  CachingHttpClient clientFor(
    Future<http.Response> Function(http.Request) handler,
  ) {
    return CachingHttpClient(
      MockClient((request) {
        networkCalls++;
        return handler(request);
      }),
      dir,
      ttl: const Duration(hours: 6),
      now: () => clock,
    );
  }

  Future<http.Response> style(http.Request request) async => http.Response(
        '{"name":"Straße"}',
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  final url = Uri.parse('https://tiles.example/styles/liberty');

  test('the second request is answered from disk, not the network', () async {
    final client = clientFor(style);

    final first = await client.get(url);
    final second = await client.get(url);

    expect(networkCalls, 1);
    expect(second.statusCode, 200);
    expect(second.body, first.body);
  });

  test('a cached answer keeps its headers, so the body decodes the same',
      () async {
    final client = clientFor(style);
    await client.get(url);

    final cached = await client.get(url);

    expect(cached.headers['content-type'], 'application/json; charset=utf-8');
    expect(cached.body, '{"name":"Straße"}');
  });

  test('binary bodies such as the sprite image survive the cache', () async {
    final png = List<int>.generate(300, (i) => i % 256);
    final client = clientFor(
      (_) async =>
          http.Response.bytes(png, 200, headers: {'content-type': 'image/png'}),
    );
    await client.get(url);

    expect((await client.get(url)).bodyBytes, png);
  });

  test('an answer older than the time limit is fetched again', () async {
    final client = clientFor(style);
    await client.get(url);

    clock = clock.add(const Duration(hours: 7));
    await client.get(url);

    expect(networkCalls, 2);
  });

  test('an answer inside the time limit is still reused', () async {
    final client = clientFor(style);
    await client.get(url);

    clock = clock.add(const Duration(hours: 5));
    await client.get(url);

    expect(networkCalls, 1);
  });

  test('failed answers are never stored', () async {
    final client = clientFor((_) async => http.Response('nope', 503));

    await client.get(url);
    final second = await client.get(url);

    expect(networkCalls, 2);
    expect(second.statusCode, 503);
  });

  test('different addresses are cached separately', () async {
    final client = clientFor(
      (request) async => http.Response(request.url.path, 200),
    );

    final a = await client.get(Uri.parse('https://tiles.example/a'));
    final b = await client.get(Uri.parse('https://tiles.example/b'));

    expect(a.body, '/a');
    expect(b.body, '/b');
  });

  test('only GET requests are cached', () async {
    final client = clientFor(style);

    await client.post(url, body: 'x');
    await client.post(url, body: 'x');

    expect(networkCalls, 2);
  });

  test('a damaged cache file is ignored and the network is used', () async {
    final client = clientFor(style);
    await client.get(url);
    for (final file in dir.listSync().whereType<File>()) {
      file.writeAsStringSync('not valid');
    }

    final again = await client.get(url);

    expect(networkCalls, 2);
    expect(jsonDecode(again.body), {'name': 'Straße'});
  });

  test('a cache folder that cannot be written does not break the request',
      () async {
    final blocked = File('${dir.path}/blocker')..writeAsStringSync('a file');
    final client = CachingHttpClient(
      MockClient((request) async => http.Response('ok', 200)),
      Directory('${blocked.path}/inside'),
      now: () => clock,
    );

    final response = await client.get(url);

    expect(response.body, 'ok');
  });

  group('concurrent requests for one address', () {
    test('are downloaded once and all get the answer', () async {
      final release = Completer<void>();
      final client = clientFor((_) async {
        await release.future;
        return http.Response('{"name":"x"}', 200);
      });

      final all =
          Future.wait([client.get(url), client.get(url), client.get(url)]);
      await Future<void>.delayed(Duration.zero);
      release.complete();
      final responses = await all;

      expect(networkCalls, 1);
      expect(responses.map((r) => r.body), everyElement('{"name":"x"}'));
      expect(dir.listSync().whereType<File>(),
          hasLength(2)); // one .body, one .meta
    });

    test('ask for themselves when the first download fails', () async {
      final release = Completer<void>();
      var attempt = 0;
      final client = clientFor((_) async {
        final mine = ++attempt;
        if (mine == 1) {
          await release.future;
          return http.Response('down', 503);
        }
        return http.Response('fine', 200);
      });

      final first = client.get(url);
      await Future<void>.delayed(Duration.zero);
      final second = client.get(url);
      await Future<void>.delayed(Duration.zero);
      release.complete();

      expect((await first).statusCode, 503);
      expect((await second).body, 'fine');
      expect(networkCalls, 2);
    });

    test('a thrown network error reaches the caller and clears the wait',
        () async {
      var shouldFail = true;
      final client = clientFor((_) async {
        if (shouldFail) throw http.ClientException('offline');
        return http.Response('back', 200);
      });

      await expectLater(client.get(url), throwsA(isA<http.ClientException>()));
      shouldFail = false;

      expect((await client.get(url)).body, 'back');
    });
  });

  group('prune', () {
    Future<CachingHttpClient> filled(
      List<String> paths, {
      int maxBytes = kMapStyleCacheMaxBytes,
      int bytes = 100,
    }) async {
      final client = CachingHttpClient(
        MockClient((r) async => http.Response('a' * bytes, 200)),
        dir,
        ttl: const Duration(hours: 6),
        maxBytes: maxBytes,
        now: () => clock,
      );
      for (final path in paths) {
        await client.get(Uri.parse('https://tiles.example/$path'));
        clock = clock.add(const Duration(minutes: 1)); // each one a bit newer
      }
      return client;
    }

    int fileCount() => dir.listSync().whereType<File>().length;

    test('removes expired answers and keeps fresh ones', () async {
      final client = await filled(['old']);
      clock = clock.add(const Duration(hours: 7));
      await filled(['fresh']);

      await client.prune();

      expect(fileCount(), 2);
      networkCalls = 0;
      await clientFor((r) async => http.Response('a', 200))
          .get(Uri.parse('https://tiles.example/fresh'));
      expect(networkCalls, 0);
    });

    test('removes the oldest answers first when over the size limit', () async {
      final client = await filled(['a', 'b', 'c'], maxBytes: 250);

      await client.prune();

      // 3 x 100 bytes > 250: only the oldest ("a") goes.
      expect(fileCount(), 4);
      networkCalls = 0;
      final probe = clientFor((r) async => http.Response('z', 200));
      await probe.get(Uri.parse('https://tiles.example/a'));
      await probe.get(Uri.parse('https://tiles.example/c'));
      expect(networkCalls, 1); // "a" fetched again, "c" still cached
    });

    test('removes damaged answers and bodies without a .meta', () async {
      final client = await filled(['a', 'b']);
      final files = dir.listSync().whereType<File>().toList();
      files.firstWhere((f) => f.path.endsWith('.meta')).writeAsStringSync('{');
      File('${dir.path}/orphan.body').writeAsBytesSync([1, 2, 3]);

      await client.prune();

      // "a"'s damaged .meta and its body are gone, "b" stays, orphan is gone.
      expect(fileCount(), 2);
      expect(File('${dir.path}/orphan.body').existsSync(), isFalse);
    });

    test('leaves files it did not write alone', () async {
      final client = await filled(['a']);
      final other = File('${dir.path}/notes.txt')..writeAsStringSync('keep');

      await client.prune();

      expect(other.existsSync(), isTrue);
    });

    test('does nothing, and does not throw, when the folder does not exist',
        () async {
      final client = CachingHttpClient(
        MockClient((r) async => http.Response('ok', 200)),
        Directory('${dir.path}/missing'),
        now: () => clock,
      );

      await client.prune();
    });
  });
}
