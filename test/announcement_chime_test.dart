import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/audio/vario_audio_service.dart';
import 'package:parabeacon/audio/vario_config.dart';

void main() {
  const config = VarioAudioConfig.xcTrack;

  int peak(List<int> pcm, int from, int to) {
    var maximum = 0;
    for (var i = from; i < to; i++) {
      final value = pcm[i * config.channels].abs();
      if (value > maximum) maximum = value;
    }
    return maximum;
  }

  test('ding is audible with the vario silent, then decays to silence', () {
    final sr = config.sampleRate;
    final pcm = debugRenderChime(config, sr * 2);
    // Strike within the first 100 ms.
    expect(peak(pcm, 0, sr ~/ 10), greaterThan(8000));
    // Mostly decayed after half a second, silent after it ended.
    expect(
      peak(pcm, sr ~/ 2, (sr * 0.6).round()),
      lessThan(peak(pcm, 0, sr ~/ 10) ~/ 4),
    );
    expect(peak(pcm, sr, sr * 2), 0);
  });

  test('ding starts without a click', () {
    final pcm = debugRenderChime(config, 8);
    expect(pcm.first.abs(), lessThan(200));
  });
}
