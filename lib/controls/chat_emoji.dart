import 'package:flutter/services.dart';

const chatMaximumMessageLength = 1000;

const pilotChatEmojis = <String>[
  '😀',
  '😃',
  '😄',
  '😁',
  '😆',
  '🥹',
  '😂',
  '🙂',
  '😉',
  '😊',
  '😍',
  '🥰',
  '😘',
  '😎',
  '🤗',
  '🤔',
  '😴',
  '😭',
  '😅',
  '🙃',
  '😋',
  '🤩',
  '😬',
  '😮',
  '😱',
  '😡',
  '👍',
  '👎',
  '👏',
  '🙌',
  '🙏',
  '🤝',
  '💪',
  '🫶',
  '❤️',
  '💙',
  '💚',
  '🎉',
  '✨',
  '🔥',
  '☀️',
  '🌤️',
  '🌈',
  '☁️',
  '🌧️',
  '💨',
  '🪂',
  '⛰️',
  '✈️',
  '🛩️',
  '🚁',
  '🧭',
  '📍',
  '💯',
  '✅',
  '❌',
];

TextEditingValue insertPilotChatEmoji(TextEditingValue value, String emoji) {
  final text = value.text;
  final selection = value.selection;
  final start = selection.isValid
      ? selection.start.clamp(0, text.length).toInt()
      : text.length;
  final end = selection.isValid
      ? selection.end.clamp(start, text.length).toInt()
      : start;
  final updatedText = text.replaceRange(start, end, emoji);
  if (updatedText.runes.length > chatMaximumMessageLength) return value;

  return value.copyWith(
    text: updatedText,
    selection: TextSelection.collapsed(offset: start + emoji.length),
    composing: TextRange.empty,
  );
}
