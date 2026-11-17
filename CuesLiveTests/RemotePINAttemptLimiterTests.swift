import XCTest
@testable import CuesLive

final class RemotePINAttemptLimiterTests: XCTestCase {
    private let start = Date(timeIntervalSinceReferenceDate: 0)

    private func fail(_ limiter: inout RemotePINAttemptLimiter, times: Int, at now: Date) {
        for _ in 0..<times {
            limiter.recordFailure(at: now)
        }
    }

    func testFirstFourWrongPINsDoNotLock() {
        var limiter = RemotePINAttemptLimiter()
        fail(&limiter, times: RemotePINAttemptLimiter.freeAttempts - 1, at: start)
        XCTAssertNil(limiter.remainingLockout(at: start))
    }

    func testFifthWrongPINLocksForThirtySeconds() {
        var limiter = RemotePINAttemptLimiter()
        fail(&limiter, times: RemotePINAttemptLimiter.freeAttempts, at: start)
        XCTAssertEqual(limiter.remainingLockout(at: start), 30)
        XCTAssertEqual(limiter.remainingLockout(at: start.addingTimeInterval(10)), 20)
        XCTAssertNil(limiter.remainingLockout(at: start.addingTimeInterval(30)))
    }

    func testEachFurtherWrongPINDoublesTheLockoutUpToTheCap() {
        var limiter = RemotePINAttemptLimiter()
        fail(&limiter, times: RemotePINAttemptLimiter.freeAttempts + 1, at: start)
        XCTAssertEqual(limiter.remainingLockout(at: start), 60)

        fail(&limiter, times: 20, at: start)
        XCTAssertEqual(limiter.remainingLockout(at: start), RemotePINAttemptLimiter.maximumLockout)
    }

    func testRightPINResetsTheCount() {
        var limiter = RemotePINAttemptLimiter()
        fail(&limiter, times: RemotePINAttemptLimiter.freeAttempts, at: start)
        limiter.recordSuccess()
        XCTAssertNil(limiter.remainingLockout(at: start))
        XCTAssertEqual(limiter.consecutiveFailures, 0)

        limiter.recordFailure(at: start)
        XCTAssertNil(limiter.remainingLockout(at: start))
    }

    func testLockoutMessageRoundsUp() {
        XCTAssertEqual(RemotePINAttemptLimiter.lockoutMessage(remaining: 29.2), "Too many wrong passwords. Try again in 30 s.")
        XCTAssertEqual(RemotePINAttemptLimiter.lockoutMessage(remaining: 61), "Too many wrong passwords. Try again in 2 min.")
    }
}
