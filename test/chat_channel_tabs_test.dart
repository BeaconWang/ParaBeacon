import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/controls/chat_page.dart';

void main() {
  test('channel chat is available only when a nonzero channel is assigned', () {
    expect(chatScopesForChannel(0), ['public', 'direct']);
    expect(chatScopesForChannel(123456), ['public', 'channel', 'direct']);
  });
}
