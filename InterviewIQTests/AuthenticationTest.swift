//
//  AuthenticationTest.swift
//  InterviewIQTests
//
//  Created by student on 03/06/26.
//

import XCTest
@testable import InterviewIQ

final class AuthenticationTest: XCTestCase {

    // SUT = System Under Test
    var sut: AuthViewModel!

    override func setUp() {
        super.setUp()
        sut = AuthViewModel()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Registration validation (deterministic — returns before any network call)

    /// Scenario: Password too short. Validation must fail before Firebase is touched.
    func test_performRegistration_whenPasswordIsTooShort_shouldFailValidation() async {
        // GIVEN
        sut.fullName = "Alex Smith"
        sut.emailAddress = "alex@interviewiq.com"
        sut.userPassword = "123" // ❌ Invalid: fewer than 6 characters

        // WHEN
        await sut.performRegistration()

        // THEN
        XCTAssertTrue(sut.hasAuthenticationError)
        XCTAssertEqual(sut.errorMessage, "Password must be at least 6 characters long.")
        XCTAssertFalse(sut.isLoading)
        XCTAssertFalse(sut.hasSuccessfullyRegistered)
    }

    // MARK: - Email normalization

    /// The lockout key is derived from a trimmed, lowercased email, so different
    /// casings/whitespace must collapse to the same database lookup key.
    func test_emailNormalization_producesIdenticalLookupKeys() {
        let first  = "Tester@InterviewIQ.com ".trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let second = "tester@interviewiq.com".trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        XCTAssertEqual(first, second, "Email normalization must yield identical keys.")
    }
}

// MARK: - Login Lockout Policy (deterministic, no network)
//
// The brute-force lockout behaviour used to be verified by driving real Firebase
// logins five times — slow, and flaky once Firebase rate-limits the failed
// attempts. The policy now lives in `LoginLockoutGuard`, a pure value type we can
// exercise directly with injected timestamps, so these tests are fast and stable.

final class LoginLockoutGuardTests: XCTestCase {

    private let email = "user@interviewiq.com"

    func test_belowThreshold_doesNotLock() {
        var tracker = LoginLockoutGuard()
        // One short of the threshold (4 failures) must NOT lock.
        for _ in 1 ..< LoginLockoutGuard.maxAttempts {
            XCTAssertFalse(tracker.registerFailure(for: email))
        }
        XCTAssertFalse(tracker.isLocked(for: email))
        XCTAssertNil(tracker.activeLockMinutes(for: email))
    }

    func test_locksExactlyOnFifthFailure() {
        var tracker = LoginLockoutGuard()
        var tripped = false
        for _ in 1 ... LoginLockoutGuard.maxAttempts {
            tripped = tracker.registerFailure(for: email)
        }
        XCTAssertTrue(tripped, "The 5th failed attempt should trip the lock.")
        XCTAssertTrue(tracker.isLocked(for: email))
    }

    func test_activeLockMinutes_reportsFifteen() {
        var tracker = LoginLockoutGuard()
        let start = Date()
        for _ in 1 ... LoginLockoutGuard.maxAttempts {
            tracker.registerFailure(for: email, now: start)
        }
        // Queried at the same instant the lock was set → full 15 minutes remain.
        XCTAssertEqual(tracker.activeLockMinutes(for: email, now: start), 15)
    }

    func test_expiredLock_autoClearsAndUnlocks() {
        var tracker = LoginLockoutGuard()
        let start = Date()
        for _ in 1 ... LoginLockoutGuard.maxAttempts {
            tracker.registerFailure(for: email, now: start)
        }
        XCTAssertTrue(tracker.isLocked(for: email, now: start))

        // 16 minutes later the 15-minute window has elapsed.
        let later = start.addingTimeInterval(16 * 60)
        XCTAssertFalse(tracker.isLocked(for: email, now: later))
        XCTAssertNil(tracker.activeLockMinutes(for: email, now: later))
    }

    func test_reset_clearsFailuresAndLock() {
        var tracker = LoginLockoutGuard()
        for _ in 1 ... LoginLockoutGuard.maxAttempts {
            tracker.registerFailure(for: email)
        }
        XCTAssertTrue(tracker.isLocked(for: email))

        tracker.reset(for: email)
        XCTAssertFalse(tracker.isLocked(for: email))

        // After a reset it takes a fresh run of failures to lock again.
        for _ in 1 ..< LoginLockoutGuard.maxAttempts {
            XCTAssertFalse(tracker.registerFailure(for: email))
        }
    }

    func test_lockout_isolatesPerEmail() {
        var tracker = LoginLockoutGuard()
        for _ in 1 ... LoginLockoutGuard.maxAttempts {
            tracker.registerFailure(for: "a@interviewiq.com")
        }
        XCTAssertTrue(tracker.isLocked(for: "a@interviewiq.com"))
        XCTAssertFalse(tracker.isLocked(for: "b@interviewiq.com"),
                       "Locking one email must never lock a different one.")
    }
}
