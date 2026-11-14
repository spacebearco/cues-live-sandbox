import Foundation

/// Ties a setlist group fader to the gains of the playing song's tracks in that group, so the
/// fader and the editor's gain knobs are one control and every song carries its own mix.
///
/// The fader shows the group's own level times its loudest track. Moving it scales every
/// track in the group by the same ratio, which keeps their balance; the group's own level
/// (a global trim, and what the Fade button ramps) is left alone.
enum GroupFaderLink {
    private static let silence = 0.000_001
    private static var maximumGain: Double { MixerFaderScale.linearGain(forDecibels: MixerFaderScale.maxBoostDB) }

    /// Where the fader sits for a group whose tracks in the song have `trackVolumes`.
    static func level(groupVolume: Double, trackVolumes: [Double]) -> Double {
        groupVolume * (trackVolumes.max() ?? 1)
    }

    /// The track gains that put the fader at `newLevel`. Silent tracks have no balance to
    /// keep, so they all take the new level. A silent group (faded out) changes nothing.
    static func trackVolumes(
        scaling trackVolumes: [Double],
        groupVolume: Double,
        toLevel newLevel: Double
    ) -> [Double] {
        guard groupVolume > silence else { return trackVolumes }
        let loudest = trackVolumes.max() ?? 0
        guard loudest > silence else {
            return trackVolumes.map { _ in min(maximumGain, newLevel / groupVolume) }
        }
        let ratio = newLevel / (groupVolume * loudest)
        return trackVolumes.map { min(maximumGain, $0 * ratio) }
    }
}
