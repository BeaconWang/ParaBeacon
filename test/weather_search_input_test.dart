import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/controls/search_query_policy.dart';

/// Reproduces the weather search bar's input handling against a real
/// [TextField] driven by simulated IME traffic.
///
/// Two opposite failure modes have to stay fixed at once, which is why the
/// composing cases below look contradictory at first glance:
///
///  * A pinyin session must not geocode its romanization fragments — they
///    match nothing and burn the 1 req/s Nominatim budget.
///  * A word Android merely *marks* as provisional must still be geocoded.
///    Gboard puts the current Latin word into a composing region for
///    autocorrect (see [TextEditingValue.composing]), so treating "composing"
///    as "ignore" meant search never ran on Android at all — the exact bug
///    where `xiaojingwan` and `小径湾` returned nothing on a phone while
///    working on Windows.
void main() {
  /// A miniature of the production widget: same controller-listener wiring,
  /// same policy, same "re-read the field when the timer fires" behaviour,
  /// recording what would have been geocoded.
  Widget harness({
    required TextEditingController controller,
    required List<String> searched,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: _SearchBarUnderTest(controller: controller, searched: searched),
      ),
    );
  }

  /// Long enough for the provisional-text quiet period to elapse.
  final afterComposingPause =
      SearchQueryPolicy.composingDebounce + const Duration(milliseconds: 100);

  testWidgets('a pinyin session issues exactly one search, for the committed '
      'characters', (tester) async {
    final controller = TextEditingController();
    final searched = <String>[];
    await tester.pumpWidget(
      harness(controller: controller, searched: searched),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();

    // The IME streams fragments while the candidate popup is open. Each one
    // carries a composing region covering the whole romanization.
    for (final fragment in ['xi', 'xian', 'xiang', 'xianggang']) {
      controller.value = TextEditingValue(
        text: fragment,
        composing: TextRange(start: 0, end: fragment.length),
      );
      // A real user pauses between keystrokes — long enough that the plain
      // 350 ms debounce would already have fired.
      await tester.pump(const Duration(milliseconds: 400));
    }

    expect(searched, isEmpty,
        reason: 'fragments typed in quick succession must not be geocoded');

    // The user picks 香港 from the IME popup: text commits, composition ends.
    controller.value = const TextEditingValue(
      text: '香港',
      selection: TextSelection.collapsed(offset: 2),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(searched, ['香港']);
  });

  testWidgets('committed Chinese input searches without needing submit',
      (tester) async {
    final controller = TextEditingController();
    final searched = <String>[];
    await tester.pumpWidget(
      harness(controller: controller, searched: searched),
    );

    controller.value = const TextEditingValue(
      text: '长沙',
      selection: TextSelection.collapsed(offset: 2),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(searched, ['长沙']);
  });

  testWidgets('a Latin word left in Gboard\'s autocorrect composing region is '
      'still searched', (tester) async {
    // The regression: on Android the composing region is the normal state
    // while typing, so "skip composing text" silently disabled search.
    final controller = TextEditingController();
    final searched = <String>[];
    await tester.pumpWidget(
      harness(controller: controller, searched: searched),
    );

    controller.value = const TextEditingValue(
      text: 'xiaojingwan',
      selection: TextSelection.collapsed(offset: 11),
      composing: TextRange(start: 0, end: 11),
    );
    await tester.pump(afterComposingPause);

    expect(searched, ['xiaojingwan']);
  });

  testWidgets('a CJK word left in a prediction composing region is still '
      'searched', (tester) async {
    // Third-party Chinese IMEs keep the committed word composing for cloud
    // correction / next-word prediction.
    final controller = TextEditingController();
    final searched = <String>[];
    await tester.pumpWidget(
      harness(controller: controller, searched: searched),
    );

    controller.value = const TextEditingValue(
      text: '小径湾',
      selection: TextSelection.collapsed(offset: 3),
      composing: TextRange(start: 0, end: 3),
    );
    await tester.pump(afterComposingPause);

    expect(searched, ['小径湾']);
  });

  testWidgets('the committed text is searched, not the romanization that was '
      'pending when the timer was set', (tester) async {
    final controller = TextEditingController();
    final searched = <String>[];
    await tester.pumpWidget(
      harness(controller: controller, searched: searched),
    );

    controller.value = const TextEditingValue(
      text: 'xiaojingwan',
      selection: TextSelection.collapsed(offset: 11),
      composing: TextRange(start: 0, end: 11),
    );
    // Commit before the provisional quiet period elapses.
    await tester.pump(const Duration(milliseconds: 200));
    controller.value = const TextEditingValue(
      text: '小径湾',
      selection: TextSelection.collapsed(offset: 3),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(searched, ['小径湾']);
  });

  testWidgets('pressing the keyboard search key works mid-composition',
      (tester) async {
    // A user who types and immediately hits "search" must not be ignored just
    // because the IME still considers the word provisional.
    final controller = TextEditingController();
    final searched = <String>[];
    await tester.pumpWidget(
      harness(controller: controller, searched: searched),
    );

    // Focus first so there is a live text-input connection to send the
    // keyboard action over.
    await tester.tap(find.byType(TextField));
    await tester.pump();

    controller.value = const TextEditingValue(
      text: 'xiaojingwan',
      selection: TextSelection.collapsed(offset: 11),
      composing: TextRange(start: 0, end: 11),
    );
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();

    expect(searched, ['xiaojingwan']);
  });

  testWidgets('English typing is unaffected and still debounces to one call',
      (tester) async {
    final controller = TextEditingController();
    final searched = <String>[];
    await tester.pumpWidget(
      harness(controller: controller, searched: searched),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();
    // Latin keyboards deliver committed text with no composing region.
    await tester.enterText(find.byType(TextField), 'Interlaken');
    await tester.pump(const Duration(milliseconds: 400));

    expect(searched, ['Interlaken']);
  });

  testWidgets('a short Latin prefix does not spend a request', (tester) async {
    final controller = TextEditingController();
    final searched = <String>[];
    await tester.pumpWidget(
      harness(controller: controller, searched: searched),
    );

    await tester.enterText(find.byType(TextField), 'in');
    await tester.pump(afterComposingPause);

    expect(searched, isEmpty);
  });

  testWidgets('clearing the field cancels a pending search', (tester) async {
    final controller = TextEditingController();
    final searched = <String>[];
    await tester.pumpWidget(
      harness(controller: controller, searched: searched),
    );

    await tester.enterText(find.byType(TextField), 'Berlin');
    // Clear before the debounce elapses.
    await tester.pump(const Duration(milliseconds: 100));
    controller.clear();
    await tester.pump(const Duration(milliseconds: 600));

    expect(searched, isEmpty);
  });
}

/// The search-bar input logic mirrored from `weather_sheet.dart`.
class _SearchBarUnderTest extends StatefulWidget {
  const _SearchBarUnderTest({required this.controller, required this.searched});

  final TextEditingController controller;
  final List<String> searched;

  @override
  State<_SearchBarUnderTest> createState() => _SearchBarUnderTestState();
}

class _SearchBarUnderTestState extends State<_SearchBarUnderTest> {
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    final value = widget.controller.value;
    _debounce?.cancel();
    if (value.text.trim().isEmpty) return;

    final delay = SearchQueryPolicy.debounceFor(value);
    if (delay == null) return;
    _debounce = Timer(delay, () {
      final text = widget.controller.text.trim();
      if (text.isEmpty) return;
      widget.searched.add(text);
    });
  }

  void _onSubmitted(String value) {
    _debounce?.cancel();
    if (!SearchQueryPolicy.canSubmit(value)) return;
    widget.searched.add(value.trim());
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: widget.controller,
        keyboardType: TextInputType.text,
        textInputAction: TextInputAction.search,
        autocorrect: false,
        enableSuggestions: false,
        onSubmitted: _onSubmitted,
      );
}
