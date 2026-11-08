import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/core/locale_provider.dart';

Future<ProviderContainer> _container(Map<String, String> saved) async {
  FlutterSecureStorage.setMockInitialValues(saved);
  final container = ProviderContainer();
  addTearDown(container.dispose);
  container.read(languageChosenProvider); // start loading
  await Future<void>.delayed(const Duration(milliseconds: 20));
  return container;
}

void main() {
  group('languageChosenProvider', () {
    test('is unknown until storage has been read', () {
      FlutterSecureStorage.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(languageChosenProvider), isNull);
    });

    test('is false on a first launch with no saved language', () async {
      final container = await _container({});

      expect(container.read(languageChosenProvider), isFalse);
    });

    test('is true when a language was saved before', () async {
      final container = await _container({'app_locale': 'ur'});

      expect(container.read(languageChosenProvider), isTrue);
    });

    test('ignores a saved value that is not a supported language', () async {
      final container = await _container({'app_locale': 'xx'});

      expect(container.read(languageChosenProvider), isFalse);
    });

    test('markChosen flips it to true', () async {
      final container = await _container({});

      container.read(languageChosenProvider.notifier).markChosen();

      expect(container.read(languageChosenProvider), isTrue);
    });
  });

  group('languageRedirect', () {
    test('waits while the saved choice is still being read', () {
      expect(
        languageRedirect(chosen: null, isLoggedIn: false, location: '/welcome'),
        isNull,
      );
    });

    test('sends a first launch to the language screen from any page', () {
      for (final page in ['/welcome', '/login', '/signup', '/']) {
        expect(
          languageRedirect(chosen: false, isLoggedIn: false, location: page),
          '/language',
          reason: page,
        );
      }
    });

    test('stays on the language screen until a language is confirmed', () {
      expect(
        languageRedirect(
          chosen: false,
          isLoggedIn: false,
          location: '/language',
        ),
        isNull,
      );
    });

    test('moves on to the welcome screen once a language is chosen', () {
      expect(
        languageRedirect(
          chosen: true,
          isLoggedIn: false,
          location: '/language',
        ),
        '/welcome',
      );
      expect(
        languageRedirect(chosen: true, isLoggedIn: false, location: '/login'),
        isNull,
      );
    });

    test('never shows it to someone who is already signed in', () {
      expect(
        languageRedirect(chosen: false, isLoggedIn: true, location: '/'),
        isNull,
      );
      expect(
        languageRedirect(
          chosen: false,
          isLoggedIn: true,
          location: '/language',
        ),
        '/',
      );
    });
  });

  test('the Urdu and English languages are the ones offered', () {
    expect(supportedLanguages.map((e) => e.$1), const [
      Locale('en'),
      Locale('ur'),
    ]);
  });
}
