import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/controls/chat_emoji.dart';

void main() {
  test('inserts an emoji at the current cursor', () {
    const value = TextEditingValue(
      text: 'Hey!',
      selection: TextSelection.collapsed(offset: 3),
    );

    final updated = insertPilotChatEmoji(value, '😀');

    expect(updated.text, 'Hey😀!');
    expect(updated.selection, const TextSelection.collapsed(offset: 5));
  });

  test('replaces selected text with the emoji', () {
    const value = TextEditingValue(
      text: 'hello',
      selection: TextSelection(baseOffset: 1, extentOffset: 4),
    );

    final updated = insertPilotChatEmoji(value, '👋');

    expect(updated.text, 'h👋o');
    expect(updated.selection, const TextSelection.collapsed(offset: 3));
  });

  test('does not exceed the chat message length limit', () {
    final text = 'a' * chatMaximumMessageLength;
    final value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );

    expect(insertPilotChatEmoji(value, '😀'), value);
  });
}
