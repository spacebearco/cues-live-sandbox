import Foundation

/// Me Time sends everything that is heard to one dedicated output (headphones, say) so the
/// song can be worked on without the room hearing it. The output is a stereo pair on the
/// selected audio device; a second device is not supported.
enum MeTimeSettings {
    static let startChannelKey = "meTimeOutputStartChannel"
    /// Outputs 3-4: the first pair past the main outs.
    static let defaultStartChannel = 3

    /// The saved pair, or the last pair the device has when it has fewer channels.
    static func destination(channelCount: Int, defaults: UserDefaults = .standard) -> OutputDestination {
        let saved = defaults.object(forKey: startChannelKey) as? Int ?? defaultStartChannel
        let pairs = OutputRoutingStore.destinations(for: channelCount).stereo
        let wanted = OutputDestination.stereoPair(startChannel: saved)
        return pairs.contains(wanted) ? wanted : (pairs.last ?? .defaultDestination)
    }
}
