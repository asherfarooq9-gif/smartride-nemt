import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:path_provider/path_provider.dart';
import 'package:smartride_core/smartride_core.dart' show ErrorReporter;

/// How long a downloaded map style is reused. Short, because the tile source
/// address inside it changes whenever OpenFreeMap publishes new map data.
const kMapStyleCacheTtl = Duration(hours: 6);

/// The most disk the cached downloads may use. The style, its tile source
/// description and the sprites are a few hundred kilobytes, so this is generous.
const kMapStyleCacheMaxBytes = 20 * 1024 * 1024;

const _kMetaSuffix = '.meta';
const _kBodySuffix = '.body';

typedef _Entry = ({List<int> body, Map<String, String> headers});

/// One saved download found on disk while cleaning up.
typedef _Stored = ({File meta, File body, DateTime savedAt, int size});

/// Keeps successful GET answers on disk, so the map style (the style file, the
/// tile source and the icon sprites) is not downloaded again on every launch.
///
/// Anything that goes wrong with the files only means a cache miss: the
/// request still goes to the network.
class CachingHttpClient extends http.BaseClient {
  CachingHttpClient(
    this._inner,
    this._dir, {
    this.ttl = kMapStyleCacheTtl,
    this.maxBytes = kMapStyleCacheMaxBytes,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final http.Client _inner;
  final Directory _dir;
  final Duration ttl;
  final int maxBytes;
  final DateTime Function() _now;

  /// Downloads that are on their way, by address. A second request for the same
  /// address waits for the first instead of downloading and saving it again.
  final Map<Uri, Future<_Entry?>> _inFlight = {};

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.method != 'GET') return _inner.send(request);

    final cached = await _read(request.url);
    if (cached != null) return _replay(request, cached.body, cached.headers);

    final running = _inFlight[request.url];
    if (running != null) {
      final shared = await running;
      if (shared != null) return _replay(request, shared.body, shared.headers);
      // The first download failed or was not a plain 200: ask for ourselves.
      return _inner.send(request);
    }
    return _download(request);
  }

  // `http.get` closes the client it is given after each call. This one is
  // shared by all calls inside [withMapStyleCache], so that is ignored and the
  // owner calls [dispose] when the whole download is over.
  @override
  void close() {}

  void dispose() => _inner.close();

  /// Downloads [request], tells anyone waiting for the same address, and saves
  /// the answer. The one that registers here is the only one that writes.
  Future<http.StreamedResponse> _download(http.BaseRequest request) async {
    final shared = Completer<_Entry?>();
    _inFlight[request.url] = shared.future;
    try {
      final response = await _inner.send(request);
      if (response.statusCode != 200) {
        shared.complete(null);
        return response;
      }
      final entry = (
        body: await response.stream.toBytes(),
        headers: _replayableHeaders(response.headers),
      );
      shared.complete(entry);
      await _write(request.url, entry.body, entry.headers);
      return _replay(request, entry.body, entry.headers);
    } finally {
      // Covers a failed download: waiters get null and go to the network.
      if (!shared.isCompleted) shared.complete(null);
      _inFlight.remove(request.url);
    }
  }

  http.StreamedResponse _replay(
    http.BaseRequest request,
    List<int> body,
    Map<String, String> headers,
  ) {
    return http.StreamedResponse(
      Stream.value(body),
      200,
      contentLength: body.length,
      request: request,
      headers: headers,
    );
  }

  // The body is stored already decompressed, so these no longer describe it.
  Map<String, String> _replayableHeaders(Map<String, String> headers) => {
        for (final entry in headers.entries)
          if (entry.key != 'content-length' && entry.key != 'content-encoding')
            entry.key: entry.value,
      };

  // A web address as a file name that never collides with another address.
  String _name(Uri url) => base64Url.encode(utf8.encode(url.toString()));

  File _bodyFile(Uri url) => File('${_dir.path}/${_name(url)}$_kBodySuffix');
  File _metaFile(Uri url) => File('${_dir.path}/${_name(url)}$_kMetaSuffix');

  bool _isExpired(DateTime savedAt) => _now().difference(savedAt) > ttl;

  Future<_Entry?> _read(Uri url) async {
    try {
      final meta = await _readMeta(_metaFile(url));
      if (meta == null || _isExpired(meta.savedAt)) return null;
      return (body: await _bodyFile(url).readAsBytes(), headers: meta.headers);
    } on FileSystemException {
      return null; // Body missing or just removed: a miss.
    }
  }

  /// The saved time and headers in a `.meta` file, or null when the file is
  /// missing, damaged, or valid JSON of the wrong shape.
  Future<({DateTime savedAt, Map<String, String> headers})?> _readMeta(
    File file,
  ) async {
    try {
      final meta =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return (
        savedAt: DateTime.fromMillisecondsSinceEpoch(meta['savedAt'] as int),
        headers: Map<String, String>.from(meta['headers'] as Map),
      );
    } on FileSystemException {
      return null; // Never saved: the normal first-time miss.
    } on FormatException {
      return null; // Damaged file: fetch it again and overwrite.
    } on TypeError {
      return null; // Valid JSON with the wrong shape.
    }
  }

  Future<void> _write(
    Uri url,
    List<int> body,
    Map<String, String> headers,
  ) async {
    try {
      await _dir.create(recursive: true);
      await _bodyFile(url).writeAsBytes(body, flush: true);
      // Written last, so a half-saved answer is never mistaken for a good one.
      await _metaFile(url).writeAsString(
        jsonEncode({
          'savedAt': _now().millisecondsSinceEpoch,
          'headers': headers,
        }),
        flush: true,
      );
    } on FileSystemException catch (e, st) {
      ErrorReporter.report('Could not save a map style download', e, st);
    }
  }

  /// Removes what is no longer useful: answers past [ttl], damaged or
  /// half-saved files, then the oldest answers until at most [maxBytes] remain.
  ///
  /// Only files this cache wrote (`.meta` and `.body`) are touched. A failure
  /// is reported and otherwise ignored, because cleanup must never stop a map.
  Future<void> prune() async {
    try {
      if (!await _dir.exists()) return;
      final files =
          await _dir.list().where((e) => e is File).cast<File>().toList();
      final paths = {for (final file in files) file.path};
      final kept = <_Stored>[];
      for (final file in files) {
        if (file.path.endsWith(_kMetaSuffix)) {
          final stored = await _inspect(file, paths);
          if (stored == null) {
            await _delete(file);
            await _delete(File(_sibling(file.path, _kBodySuffix)));
          } else {
            kept.add(stored);
          }
        } else if (file.path.endsWith(_kBodySuffix) &&
            !paths.contains(_sibling(file.path, _kMetaSuffix))) {
          await _delete(file); // A body whose .meta was never written.
        }
      }
      await _trimToSize(kept);
    } on FileSystemException catch (e, st) {
      ErrorReporter.report('Could not clean the map style cache', e, st);
    }
  }

  // The `.body` path for a `.meta` path and the other way round.
  String _sibling(String path, String newSuffix) {
    final cut = path.endsWith(_kMetaSuffix)
        ? path.length - _kMetaSuffix.length
        : path.length - _kBodySuffix.length;
    return '${path.substring(0, cut)}$newSuffix';
  }

  /// The saved download behind [metaFile], or null when it should go: expired,
  /// damaged, or without its body.
  Future<_Stored?> _inspect(File metaFile, Set<String> paths) async {
    final bodyPath = _sibling(metaFile.path, _kBodySuffix);
    final meta = await _readMeta(metaFile);
    if (meta == null || _isExpired(meta.savedAt)) return null;
    if (!paths.contains(bodyPath)) return null;
    final body = File(bodyPath);
    return (
      meta: metaFile,
      body: body,
      savedAt: meta.savedAt,
      size: await body.length(),
    );
  }

  Future<void> _trimToSize(List<_Stored> kept) async {
    var total = kept.fold<int>(0, (sum, stored) => sum + stored.size);
    kept.sort((a, b) => a.savedAt.compareTo(b.savedAt));
    for (final stored in kept) {
      if (total <= maxBytes) return;
      await _delete(stored.meta);
      await _delete(stored.body);
      total -= stored.size;
    }
  }

  Future<void> _delete(File file) async {
    try {
      await file.delete();
    } on PathNotFoundException {
      // Already gone.
    }
  }
}

/// Runs [body] with every `http` call inside it going through a disk cache.
///
/// Used around the map style download. It does nothing on the web, which has
/// no files, and falls back to the plain network if the cache folder cannot be
/// made.
Future<T> withMapStyleCache<T>(Future<T> Function() body) async {
  if (kIsWeb) return body();
  final Directory dir;
  try {
    final base = await getTemporaryDirectory();
    dir = await Directory('${base.path}/map_style').create(recursive: true);
  } on Exception catch (e, st) {
    ErrorReporter.report('Map style cache is unavailable', e, st);
    return body();
  }
  final client = CachingHttpClient(IOClient(), dir);
  try {
    await client.prune();
    return await http.runWithClient(body, () => client);
  } finally {
    client.dispose();
  }
}
