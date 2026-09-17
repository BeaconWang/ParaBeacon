import 'package:flutter/services.dart';

import '../data/cjk.dart';

/// Decides *when* a search field's contents should be geocoded.
///
/// ## The two behaviours this has to reconcile
///
/// **A CJK IME composes.** Typing 小径湾 with pinyin does not deliver finished
/// characters keystroke by keystroke: the IME streams romanized fragments
/// ("x", "xi", "xia" … "xiaojingwan") with an active composing region and only
/// commits 小径湾 once the user picks a candidate. Geocoding each fragment
/// matches nothing and burns the 1 req/s Nominatim budget, so the real query
/// lands late and throttled.
///
/// **But Latin input on Android composes too.** This is the part that is easy
/// to get wrong, and it is documented on [TextEditingValue.composing]: the
/// Android Gboard English keyboard *"puts the current word under the caret
/// into a composing region to indicate the word is subject to autocorrect or
/// prediction changes"*. So on Android a composing region is the normal state
/// while typing any word, in any script. Desktop keyboards do not do this,
/// which is why treating "composing" as "not a real query" appears to work on
/// Windows and silently breaks every search on Android.
///
/// ## Therefore: composing delays, it never vetoes
///
/// Provisional text gets a longer quiet period ([composingDebounce]) rather
/// than being discarded. Fragments arriving while the user actively types keep
/// resetting that timer, so a pinyin session still collapses to (at most) one
/// request; but text the IME simply leaves marked as provisional — Gboard's
/// autocorrect region, a third-party IME's prediction region — is eventually
/// searched instead of being dropped on the floor forever.
///
/// An explicit submit (the keyboard's search key) is always honoured: see
/// [canSubmit]. The user pressing "search" is not provisional.
class SearchQueryPolicy {
  SearchQueryPolicy._();

  /// Minimum number of characters before a query is worth sending on its own.
  ///
  /// CJK is information-dense — 香港 and 长沙 are complete place names at two
  /// characters — whereas two Latin letters are almost always a prefix the
  /// user is still typing. An explicit submit bypasses this.
  static const int minCjkLength = 2;
  static const int minLatinLength = 3;

  /// Quiet period for text the IME has committed.
  static const Duration committedDebounce = Duration(milliseconds: 350);

  /// Quiet period for text still marked provisional by the IME.
  ///
  /// Long enough that consecutive keystrokes of a pinyin session keep
  /// resetting it (so the fragments are never sent), short enough that a
  /// finished word Gboard merely left in its autocorrect region is still
  /// searched while the user waits.
  static const Duration composingDebounce = Duration(milliseconds: 900);

  /// How long to wait before geocoding [value], or null when it should not be
  /// geocoded at all (empty, or too short to be meaningful).
  ///
  /// Callers should re-read the field when the timer fires rather than reusing
  /// [value]: during a long composing wait the IME may have committed
  /// something quite different (`xiaojingwan` → 小径湾), and the freshest text
  /// is the one the user is actually looking at.
  static Duration? debounceFor(TextEditingValue value) {
    if (!isLongEnough(value.text)) return null;
    return isComposing(value) ? composingDebounce : committedDebounce;
  }

  /// Whether an explicit submit should be geocoded.
  ///
  /// Deliberately permissive: the user pressed the search key, so neither an
  /// active composing region nor a below-threshold length should block them.
  static bool canSubmit(String text) => text.trim().isNotEmpty;

  /// Whether [value] can be searched on the short [committedDebounce] — i.e.
  /// it is long enough and the IME is not mid-composition.
  ///
  /// This is a "no extra waiting needed" test, not a permission check; text
  /// that fails it is delayed by [debounceFor], never discarded.
  static bool isReadyToSearch(TextEditingValue value) {
    if (isComposing(value)) return false;
    return isLongEnough(value.text);
  }

  /// Whether the IME currently marks part of [value] as provisional.
  static bool isComposing(TextEditingValue value) {
    final composing = value.composing;
    // `isValid` alone is not enough: some IMEs report a collapsed (empty)
    // range, which is not an actual composition in progress.
    return composing.isValid && !composing.isCollapsed;
  }

  /// Whether [text] clears the minimum-length bar for its script.
  static bool isLongEnough(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    // Count runes, not code units, so a CJK character counts as one.
    final runeCount = trimmed.runes.length;
    final threshold = containsCjk(trimmed) ? minCjkLength : minLatinLength;
    return runeCount >= threshold;
  }

  /// Whether [text] contains CJK ideographs or kana.
  ///
  /// Delegates to the shared [Cjk] table, which the geocoding provider chain
  /// also consults when deciding whether AMap can answer a query.
  static bool containsCjk(String text) => Cjk.contains(text);
}
