import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/controls/search_query_policy.dart';

void main() {
  // Helper: text with an active IME composition over [composing].
  TextEditingValue composing(String text, {int start = 0, int? end}) =>
      TextEditingValue(
        text: text,
        composing: TextRange(start: start, end: end ?? text.length),
      );

  TextEditingValue committed(String text) => TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );

  group('SearchQueryPolicy.isComposing', () {
    test('an active composing range is detected', () {
      expect(SearchQueryPolicy.isComposing(composing('xiang')), isTrue);
    });

    test('committed text has no composition', () {
      expect(SearchQueryPolicy.isComposing(committed('香港')), isFalse);
      expect(SearchQueryPolicy.isComposing(committed('Hong Kong')), isFalse);
    });

    test('a collapsed range is not treated as composing', () {
      // Some IMEs report an empty range; that is not a live composition.
      expect(
        SearchQueryPolicy.isComposing(
          const TextEditingValue(
            text: 'Bern',
            composing: TextRange(start: 2, end: 2),
          ),
        ),
        isFalse,
      );
    });
  });

  group('SearchQueryPolicy.isLongEnough', () {
    test('two CJK characters are a complete place name', () {
      expect(SearchQueryPolicy.isLongEnough('香港'), isTrue);
      expect(SearchQueryPolicy.isLongEnough('长沙'), isTrue);
    });

    test('a single CJK character is too short', () {
      expect(SearchQueryPolicy.isLongEnough('香'), isFalse);
    });

    test('Latin needs three characters', () {
      expect(SearchQueryPolicy.isLongEnough('be'), isFalse);
      expect(SearchQueryPolicy.isLongEnough('ber'), isTrue);
    });

    test('whitespace-only and empty text are rejected', () {
      expect(SearchQueryPolicy.isLongEnough(''), isFalse);
      expect(SearchQueryPolicy.isLongEnough('   '), isFalse);
    });

    test('surrounding whitespace is ignored', () {
      expect(SearchQueryPolicy.isLongEnough('  香港  '), isTrue);
    });
  });

  group('SearchQueryPolicy.containsCjk', () {
    test('detects Han, kana and mixed strings', () {
      expect(SearchQueryPolicy.containsCjk('香港'), isTrue);
      expect(SearchQueryPolicy.containsCjk('とうきょう'), isTrue);
      expect(SearchQueryPolicy.containsCjk('Tokyo 東京'), isTrue);
    });

    test('plain Latin and pinyin romanization are not CJK', () {
      expect(SearchQueryPolicy.containsCjk('Hong Kong'), isFalse);
      // This is the crux: pinyin fragments are indistinguishable from Latin
      // text by content alone, which is why the composing region — not the
      // characters — must gate the search.
      expect(SearchQueryPolicy.containsCjk('xianggang'), isFalse);
    });
  });

  group('SearchQueryPolicy.isReadyToSearch', () {
    test('pinyin fragments mid-composition are not ready immediately', () {
      // Typing 香港 on an Android pinyin IME. "Not ready" means "wait longer",
      // not "discard" — see the debounceFor group below.
      for (final fragment in [
        'x',
        'xi',
        'xia',
        'xian',
        'xiang',
        'xiangg',
        'xianggan',
        'xianggang',
      ]) {
        expect(
          SearchQueryPolicy.isReadyToSearch(composing(fragment)),
          isFalse,
          reason: 'composing fragment "$fragment" must not be sent at once',
        );
      }
    });

    test('the committed CJK result does trigger a search', () {
      expect(SearchQueryPolicy.isReadyToSearch(committed('香港')), isTrue);
    });

    test('committed Latin input still searches on the normal rules', () {
      expect(SearchQueryPolicy.isReadyToSearch(committed('Interlaken')), isTrue);
      expect(SearchQueryPolicy.isReadyToSearch(committed('in')), isFalse);
    });

    test('a committed but too-short CJK query waits', () {
      expect(SearchQueryPolicy.isReadyToSearch(committed('香')), isFalse);
    });

    test('exactly one value is immediately ready across a pinyin session', () {
      final session = <TextEditingValue>[
        composing('x'),
        composing('xi'),
        composing('xia'),
        composing('xian'),
        composing('xiang'),
        composing('xiangg'),
        composing('xianggan'),
        composing('xianggang'),
        committed('香港'), // user picks the candidate
      ];
      final ready =
          session.where(SearchQueryPolicy.isReadyToSearch).toList();
      expect(ready, hasLength(1));
      expect(ready.single.text, '香港');
    });
  });

  group('SearchQueryPolicy.debounceFor', () {
    test('committed text waits only the short debounce', () {
      expect(
        SearchQueryPolicy.debounceFor(committed('香港')),
        SearchQueryPolicy.committedDebounce,
      );
      expect(
        SearchQueryPolicy.debounceFor(committed('Interlaken')),
        SearchQueryPolicy.committedDebounce,
      );
    });

    test('provisional text is delayed, never dropped', () {
      // The crux of the Android bug: Gboard keeps the current Latin word in a
      // composing region, so a null here would disable search on the phone.
      expect(
        SearchQueryPolicy.debounceFor(composing('xiaojingwan')),
        SearchQueryPolicy.composingDebounce,
      );
      expect(
        SearchQueryPolicy.debounceFor(composing('小径湾')),
        SearchQueryPolicy.composingDebounce,
      );
    });

    test('the provisional wait is longer than the committed one', () {
      // Otherwise fast typing could not outrun it and fragments would leak.
      expect(
        SearchQueryPolicy.composingDebounce,
        greaterThan(SearchQueryPolicy.committedDebounce),
      );
    });

    test('text too short or empty is not scheduled at all', () {
      expect(SearchQueryPolicy.debounceFor(committed('in')), isNull);
      expect(SearchQueryPolicy.debounceFor(committed('香')), isNull);
      expect(SearchQueryPolicy.debounceFor(committed('   ')), isNull);
      expect(SearchQueryPolicy.debounceFor(composing('xi')), isNull);
    });
  });

  group('SearchQueryPolicy.canSubmit', () {
    test('an explicit submit is honoured even when short', () {
      // The user pressed the search key; length heuristics no longer apply.
      expect(SearchQueryPolicy.canSubmit('in'), isTrue);
      expect(SearchQueryPolicy.canSubmit('香'), isTrue);
      expect(SearchQueryPolicy.canSubmit('小径湾'), isTrue);
    });

    test('an empty or whitespace-only submit is ignored', () {
      expect(SearchQueryPolicy.canSubmit(''), isFalse);
      expect(SearchQueryPolicy.canSubmit('   '), isFalse);
    });
  });
}
