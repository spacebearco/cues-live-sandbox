import Foundation

/// Slows down guessing the remote PIN. The PIN has only four digits, and a wrong one just drops
/// the connection, so without a limit a client could reconnect and try them all in minutes.
///
/// After `freeAttempts` wrong PINs in a row the host refuses every PIN for `firstLockout`, and
/// each further wrong PIN doubles the wait, up to `maximumLockout`. A right PIN resets it. The
/// count is for the whole host, not per address, so reconnecting does not start it over.
struct RemotePINAttemptLimiter {
    static let freeAttempts = 5
    static let firstLockout: TimeInterval = 30
    static let maximumLockout: TimeInterval = 15 * 60

    private(set) var consecutiveFailures = 0
    private var lockedUntil: Date?

    /// Seconds left before the host checks PINs again, or `nil` when it is not locked.
    func remainingLockout(at now: Date) -> TimeInterval? {
        guard let lockedUntil, lockedUntil > now else { return nil }
        return lockedUntil.timeIntervalSince(now)
    }

    mutating func recordFailure(at now: Date) {
        consecutiveFailures += 1
        let lockoutsSoFar = consecutiveFailures - Self.freeAttempts
        guard lockoutsSoFar >= 0 else { return }
        let lockout = min(Self.maximumLockout, Self.firstLockout * pow(2, Double(lockoutsSoFar)))
        lockedUntil = now.addingTimeInterval(lockout)
    }

    mutating func recordSuccess() {
        consecutiveFailures = 0
        lockedUntil = nil
    }

    /// What the client is told while the host is locked.
    static func lockoutMessage(remaining: TimeInterval) -> String {
        let seconds = Int(remaining.rounded(.up))
        if seconds < 60 {
            return "Too many wrong passwords. Try again in \(seconds) s."
        }
        let minutes = Int((remaining / 60).rounded(.up))
        return "Too many wrong passwords. Try again in \(minutes) min."
    }
}
