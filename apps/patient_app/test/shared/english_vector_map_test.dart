import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/shared/english_vector_map.dart';

const _bilingual = [
  'case',
  ['has', 'name:nonlatin'],
  [
    'concat',
    ['get', 'name:latin'],
    ' ',
    ['get', 'name:nonlatin']
  ],
  [
    'coalesce',
    ['get', 'name_en'],
    ['get', 'name'],
  ],
];

Map<String, dynamic> _style() => {
      'version': 8,
      'layers': [
        {
          'id': 'road-name',
          'type': 'symbol',
          'layout': {'text-field': _bilingual, 'text-size': 12},
        },
        {
          'id': 'shield',
          'type': 'symbol',
          'layout': {
            'text-field': [
              'to-string',
              ['get', 'ref']
            ],
          },
        },
        {'id': 'water', 'type': 'fill'},
      ],
    };

void main() {
  test('labels that print Latin plus the local script become English-first',
      () {
    final out = withEnglishLabels(_style());

    final layer = (out['layers'] as List)[0] as Map<String, dynamic>;
    final layout = layer['layout'] as Map<String, dynamic>;
    expect(layout['text-field'], [
      'coalesce',
      ['get', 'name:latin'],
      ['get', 'name_en'],
      ['get', 'name'],
    ]);
    expect(layout['text-size'], 12, reason: 'other layout keys are kept');
  });

  test('road shields and layers without labels are left as they were', () {
    final out = withEnglishLabels(_style());
    final layers = out['layers'] as List;

    expect(
      (layers[1] as Map)['layout'],
      {
        'text-field': [
          'to-string',
          ['get', 'ref']
        ],
      },
    );
    expect(layers[2], {'id': 'water', 'type': 'fill'});
  });

  test('does not change the style it was given', () {
    final original = _style();

    withEnglishLabels(original);

    expect(original, _style());
  });

  group('awaitBothKeepingFirstError', () {
    Future<int> failsWith(Object error) async {
      await Future<void>.delayed(const Duration(milliseconds: 1));
      throw error;
    }

    test('returns both results', () async {
      final (a, b) = await awaitBothKeepingFirstError(
        Future.value(1),
        Future.value('two'),
      );

      expect((a, b), (1, 'two'));
    });

    test('rethrows the original error, not a ParallelWaitError', () async {
      await expectLater(
        awaitBothKeepingFirstError(
          failsWith(StateError('style 503')),
          Future.value('ok'),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('keeps the original stack trace', () async {
      try {
        await awaitBothKeepingFirstError(Future.value(1), failsWith('boom'));
        fail('should have thrown');
      } catch (e, st) {
        expect(e, 'boom');
        expect(st.toString(), contains('failsWith'));
      }
    });

    test('when both fail, the first one is reported', () async {
      await expectLater(
        awaitBothKeepingFirstError(
          failsWith(StateError('first')),
          failsWith(ArgumentError('second')),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('waits for the slower future even when one has failed', () async {
      var slowFinished = false;
      final slow = Future<int>.delayed(const Duration(milliseconds: 30), () {
        slowFinished = true;
        return 2;
      });

      await expectLater(
        awaitBothKeepingFirstError(failsWith(StateError('x')), slow),
        throwsA(isA<StateError>()),
      );

      expect(slowFinished, isTrue);
    });
  });
}
