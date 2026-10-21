import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/audio/vario_audio_service.dart';
import 'package:parabeacon/audio/vario_config.dart';

/// Whether the second half of a 2 s render (after speed smoothing settles)
/// contains audible output.
bool _audibleAt(VarioAudioConfig config, double speed) {
  final frames = config.sampleRate * 2;
  final pcm = debugRenderVario(config, speed, frames);
  for (var i = frames ~/ 2; i < frames; i++) {
    if (pcm[i * config.channels].abs() > 100) return true;
  }
  return false;
}

void main() {
  const base = VarioAudioConfig.xcTrack; // sink threshold -2.0 m/s

  test('range between sink threshold and 0 is silent by default', () {
    expect(base.sinkZoneCueEnabled, isFalse);
    expect(_audibleAt(base, -1.0), isFalse);
  });

  test('sink notification zone plays the deadband cue below 0 m/s', () {
    final config = base.copyWith(sinkZoneCueEnabled: true);
    expect(_audibleAt(config, -1.0), isTrue);
    expect(_audibleAt(config, -0.1), isTrue);
  });

  test('sink notification zone does not change other ranges', () {
    final config = base.copyWith(sinkZoneCueEnabled: true);
    // Near-lift cue still plays at/above 0 m/s; sink alarm still plays below
    // the sink threshold.
    expect(_audibleAt(config, 0.1), isTrue);
    expect(_audibleAt(config, -3.0), isTrue);
    // With the near-lift cue disabled, only the sink side cue plays.
    final sinkOnly = config.copyWith(nearLiftEnabled: false);
    expect(_audibleAt(sinkOnly, -1.0), isTrue);
    expect(_audibleAt(sinkOnly, 0.1), isFalse);
  });
}
