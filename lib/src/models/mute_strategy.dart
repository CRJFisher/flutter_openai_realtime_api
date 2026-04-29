import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

/// How the WebRTC transport handles the local microphone while the assistant
/// is speaking.
///
/// Android's `getUserMedia` echo cancellation does not reliably stop the
/// loudspeaker output from being picked up by the mic when the user is not
/// wearing headphones. `aggressive` mitigates this by replacing the outbound
/// audio track with `null` for the duration of assistant speech, which
/// stops RTP transmission entirely. Other platforms have hardware AEC that
/// works well enough for `standard` to be safe.
enum MuteStrategy {
  /// Microphone stays open during assistant audio. Use only with headphones
  /// or on platforms with reliable hardware echo cancellation.
  off,

  /// Toggle `track.enabled`. RTP packets continue (silent), so any echo
  /// suppressor on the server side still receives audio. Recommended for
  /// iOS, macOS, desktop, and Web.
  standard,

  /// Replace the outbound audio track with `null` while the assistant
  /// speaks. Stops RTP entirely. Recommended for Android.
  aggressive,

  /// `aggressive` on Android, `standard` on every other platform.
  auto;

  /// Whether muting is performed at all.
  bool get enabled => this != MuteStrategy.off;

  /// Whether the WebRTC transport should replace the track instead of just
  /// flipping `track.enabled`.
  bool get replaceTrack {
    switch (this) {
      case MuteStrategy.off:
      case MuteStrategy.standard:
        return false;
      case MuteStrategy.aggressive:
        return true;
      case MuteStrategy.auto:
        return _platformDefault.replaceTrack;
    }
  }

  /// Strategy chosen for the current platform when `auto` is requested.
  static MuteStrategy get _platformDefault {
    if (kIsWeb) return MuteStrategy.standard;
    return defaultTargetPlatform == TargetPlatform.android
        ? MuteStrategy.aggressive
        : MuteStrategy.standard;
  }
}
