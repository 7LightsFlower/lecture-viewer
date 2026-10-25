/// Whether [TtsSoloudPaneEngine.clearBuffer] should keep playback intent when
/// switching the selected language.
///
/// Intent is preserved even when the target language has no TTS route, so a
/// detour through an unsupported language does not stop playback after returning
/// to a TTS-supported language.
bool preserveTtsPlaybackOnLanguageChange({
  required bool userWantsPlayback,
}) =>
    userWantsPlayback;
