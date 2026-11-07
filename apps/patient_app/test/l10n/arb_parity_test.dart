import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _load(String name) =>
    jsonDecode(File('lib/l10n/$name').readAsStringSync())
        as Map<String, dynamic>;

Set<String> _messageKeys(Map<String, dynamic> arb) =>
    arb.keys.where((k) => !k.startsWith('@')).toSet();

void main() {
  final en = _load('app_en.arb');
  final ur = _load('app_ur.arb');

  test('every English message has an Urdu translation, and the reverse', () {
    final missingInUrdu = _messageKeys(en).difference(_messageKeys(ur));
    final missingInEnglish = _messageKeys(ur).difference(_messageKeys(en));

    expect(missingInUrdu, isEmpty, reason: 'add these to app_ur.arb');
    expect(missingInEnglish, isEmpty, reason: 'add these to app_en.arb');
  });

  test('no Urdu message is left empty', () {
    final blank = [
      for (final k in _messageKeys(ur))
        if ((ur[k] as String).trim().isEmpty) k,
    ];

    expect(blank, isEmpty);
  });
}
