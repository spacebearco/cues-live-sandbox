import Foundation

extension PlaybackCoordinator {
    /// The Fade button's length in seconds: its bar count (`FadeButtonSettings`) at the tempo and
    /// meter of the bar playing now.
    var fadeButtonDuration: TimeInterval {
        FadeButtonSettings.duration(
            at: currentTime,
            tempoChanges: currentWaveformSnapshot?.tempoChanges ?? [],
            timeSignatureChanges: currentWaveformSnapshot?.timeSignatureChanges ?? []
        )
    }
}
