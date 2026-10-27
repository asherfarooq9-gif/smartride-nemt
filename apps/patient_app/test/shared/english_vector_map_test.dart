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
}
