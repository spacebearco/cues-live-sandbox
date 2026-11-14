import Foundation

/// Me Time sends everything that is heard to one dedicated output (headphones, say) so the
/// song can be worked on without the room hearing it. The output is a stereo pair on the
/// selected audio device, or on another device: the whole engine then plays from that device
/// until Me Time ends.
enum MeTimeSettings {
    static let startChannelKey = "meTimeOutputStartChannel"
    /// UID of the Me Time device. Empty means the selected audio device.
    static let deviceKey = "meTimeOutputDeviceUID"
    /// Outputs 3-4 on the selected device: the first pair past the main outs.
    static let defaultStartChannel = 3

    struct Output: Equatable {
        /// The other device to play from, or `nil` to stay on the selected one.
        var device: AudioOutputDevice?
        var destination: OutputDestination
    }

    /// Where Me Time plays. A saved device that is missing, or is the selected device itself,
    /// falls back to the selected device.
    static func output(
        mainDeviceUID: String?,
        mainChannelCount: Int,
        devices: [AudioOutputDevice],
        defaults: UserDefaults = .standard
    ) -> Output {
        let savedUID = defaults.string(forKey: deviceKey) ?? ""
        if !savedUID.isEmpty, savedUID != mainDeviceUID,
           let device = devices.first(where: { $0.id == savedUID }) {
            return Output(
                device: device,
                destination: destination(channelCount: device.channelCount, defaults: defaults)
            )
        }
        return Output(device: nil, destination: destination(channelCount: mainChannelCount, defaults: defaults))
    }

    /// True when a Me Time device other than the selected one is set, whether or not it is
    /// plugged in.
    static func usesAnotherDevice(mainDeviceUID: String?, defaults: UserDefaults = .standard) -> Bool {
        let savedUID = defaults.string(forKey: deviceKey) ?? ""
        return !savedUID.isEmpty && savedUID != mainDeviceUID
    }

    /// The saved pair, or the last pair the device has when it has fewer channels.
    static func destination(channelCount: Int, defaults: UserDefaults = .standard) -> OutputDestination {
        let saved = defaults.object(forKey: startChannelKey) as? Int ?? defaultStartChannel
        let pairs = OutputRoutingStore.destinations(for: channelCount).stereo
        let wanted = OutputDestination.stereoPair(startChannel: saved)
        return pairs.contains(wanted) ? wanted : (pairs.last ?? .defaultDestination)
    }
}
