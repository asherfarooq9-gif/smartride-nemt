import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/core/providers.dart';

final _token = StateProvider<String?>((ref) => null);

ProviderContainer _container({Map<String, String> stored = const {}}) {
  FlutterSecureStorage.setMockInitialValues({...stored}); // writable copy
  final c = ProviderContainer(overrides: [
    sessionTokenProvider.overrideWith((ref) => ref.watch(_token)),
  ]);
  addTearDown(c.dispose);
  return c;
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('sign up and login are always light, even if dark was saved', () async {
    final c = _container(stored: {'app_theme_mode': 'dark'});
    c.read(themeModeProvider);
    await _settle();

    expect(c.read(effectiveThemeModeProvider), ThemeMode.light);
  });

  test('a new account starts light, not following the system theme', () async {
    final c = _container();
    c.read(_token.notifier).state = 'token';
    await _settle();

    expect(c.read(effectiveThemeModeProvider), ThemeMode.light);
  });

  test('after login the user can switch to dark and back', () async {
    final c = _container();
    c.read(_token.notifier).state = 'token';

    await c.read(themeModeProvider.notifier).setDark(true);
    expect(c.read(effectiveThemeModeProvider), ThemeMode.dark);

    await c.read(themeModeProvider.notifier).setDark(false);
    expect(c.read(effectiveThemeModeProvider), ThemeMode.light);
  });

  test('a saved dark choice applies after login', () async {
    final c = _container(stored: {'app_theme_mode': 'dark'});
    c.read(themeModeProvider);
    await _settle();
    c.read(_token.notifier).state = 'token';

    expect(c.read(effectiveThemeModeProvider), ThemeMode.dark);
  });

  test('signing out returns to the light login screen', () async {
    final c = _container();
    c.read(_token.notifier).state = 'token';
    await c.read(themeModeProvider.notifier).setDark(true);

    c.read(_token.notifier).state = null;

    expect(c.read(effectiveThemeModeProvider), ThemeMode.light);
  });
}
