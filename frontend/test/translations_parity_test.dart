import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('All six primary language translation files have identical keys', () {
    const mainLanguages = ['en', 'hi', 'ta', 'te', 'kn', 'ml'];
    final keySets = <String, Set<String>>{};

    for (final lang in mainLanguages) {
      final file = File('assets/translations/$lang.json');
      expect(file.existsSync(), isTrue, reason: 'File $lang.json must exist');
      final content = file.readAsStringSync();
      final map = json.decode(content) as Map<String, dynamic>;
      keySets[lang] = map.keys.toSet();
    }

    final enKeys = keySets['en']!;
    expect(enKeys.isNotEmpty, isTrue, reason: 'en.json must not be empty');

    for (final lang in mainLanguages) {
      if (lang == 'en') continue;
      final currentKeys = keySets[lang]!;
      final missingInCurrent = enKeys.difference(currentKeys);
      final extraInCurrent = currentKeys.difference(enKeys);

      expect(
        missingInCurrent,
        isEmpty,
        reason: 'Language $lang is missing keys present in en.json: $missingInCurrent',
      );
      expect(
        extraInCurrent,
        isEmpty,
        reason: 'Language $lang has extra keys not in en.json: $extraInCurrent',
      );
    }
  });
}
