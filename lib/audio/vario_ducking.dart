import 'dart:async';

import 'altitude_announcement_settings.dart';
import 'altitude_announcement_speaker.dart';
import 'vario_audio_service.dart';

/// Lowers the vario tone while a voice announcement is spoken so the voice
/// stays intelligible when the vario is loud, then restores it.
///
/// Only a temporary attenuation is applied on the vario engine; the user's
/// vario volume setting is never modified.
class VarioDuckingController {
  VarioDuckingController({
    AltitudeAnnouncementSpeaker? speaker,
    AltitudeAnnouncementSettings? settings,
    VarioAudioService? vario,
  }) : _speaker = speaker ?? AltitudeAnnouncementSpeaker.instance,
       _settings = settings ?? AltitudeAnnouncementSettings.instance,
       _vario = vario ?? VarioAudioService.instance;

  final AltitudeAnnouncementSpeaker _speaker;
  final AltitudeAnnouncementSettings _settings;
  final VarioAudioService _vario;

  /// Keeps the vario lowered briefly after speech ends, so it does not jump
  /// back between the end of the utterance and the audio tail.
  static const _releaseDelay = Duration(milliseconds: 400);

  Timer? _releaseTimer;
  bool _attached = false;

  void attach() {
    if (_attached) return;
    _attached = true;
    _speaker.speaking.addListener(_update);
    _settings.addListener(_update);
    _update();
  }

  void _update() {
    final duck = _settings.duckVario && _speaker.speaking.value;
    if (duck) {
      _releaseTimer?.cancel();
      _releaseTimer = null;
      _vario.setDuckLevel(_settings.varioDuckLevel);
      return;
    }
    if (!_settings.duckVario) {
      _releaseTimer?.cancel();
      _releaseTimer = null;
      _vario.setDuckLevel(1.0);
      return;
    }
    if (_vario.duckLevel >= 1.0 || _releaseTimer != null) return;
    _releaseTimer = Timer(_releaseDelay, () {
      _releaseTimer = null;
      if (!_speaker.speaking.value) _vario.setDuckLevel(1.0);
    });
  }

  void dispose() {
    if (!_attached) return;
    _attached = false;
    _releaseTimer?.cancel();
    _releaseTimer = null;
    _speaker.speaking.removeListener(_update);
    _settings.removeListener(_update);
    _vario.setDuckLevel(1.0);
  }
}
