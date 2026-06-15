// Location: InterviewApp/Features/Authentication/AuthViewModel.swift

import Foundation
import FirebaseAuth
import Combine

class AuthViewModel: ObservableObject {
    // MARK: - Published Properties (UI Binding States)
    @Published var emailAddress = ""
    @Published var userPassword = ""
    @Published var fullName = ""

    @Published var isLoading = false
    @Published var hasAuthenticationError = false
    @Published var errorMessage = ""
    @Published var isAccountLocked = false
    @Published var hasSuccessfullyRegistered = false

    // Password reset
    @Published var showPasswordResetConfirmation = false
    @Published var passwordResetMessage = ""

    // MARK: - Core Security Storage (Per-Account Lock Tracking)
    // Lockout bookkeeping lives in a small value type so the policy (when an
    // account locks, for how long, per email) can be unit-tested deterministically
    // — without driving real Firebase logins, which are slow and rate-limited.
    private var lockoutGuard = LoginLockoutGuard()

    // MARK: - Profile Persistence
    private let userRepository = UserRepository()

    // MARK: - Audit Logging (FR-11)
    // Records authentication events (registration + login attempts).
    private let auditLogger = AuditLogger()

    // MARK: - Authentication Pipelines
    
    /// Handles targeted conditional user logins matching requirement 3a.1
    func performLogin() async {
        let normalizedEmail = emailAddress.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // 1. Pre-Auth Security Gatekeeper: Check lock status for this specific email
        // identifier. A naturally-expired lock is cleared inside the guard.
        if let remainingMinutes = lockoutGuard.activeLockMinutes(for: normalizedEmail) {
            await MainActor.run {
                self.isAccountLocked = true
                self.hasAuthenticationError = true
                self.errorMessage = "Account temporarily locked for 15 minutes. Try again in \(remainingMinutes) min(s)."
            }
            return
        }
        
        // 2. Initialize processing UI state
        await MainActor.run {
            self.isLoading = true
            self.hasAuthenticationError = false
            self.errorMessage = ""
            self.isAccountLocked = false
        }
        
        do {
            // 3. Dispatch auth credentials payload request to Firebase
            let result = try await Auth.auth().signIn(withEmail: emailAddress, password: userPassword)

            // On Authentication Success: Flush failed records for this email
            lockoutGuard.reset(for: normalizedEmail)

            await auditLogger.log(
                .loginSucceeded,
                actorId: result.user.uid,
                targetType: "user",
                targetId: result.user.uid,
                details: normalizedEmail
            )
            
            await MainActor.run {
                self.isLoading = false
            }
            
        } catch {
            let authError = error as NSError

            await auditLogger.log(
                .loginFailed,
                actorId: normalizedEmail,
                targetType: "user",
                targetId: normalizedEmail,
                details: "code=\(authError.code)"
            )

            await MainActor.run {
                self.isLoading = false
                self.hasAuthenticationError = true

                // 4. Intercept errors to apply contextual security logic
                switch authError.code {
                    
                case AuthErrorCode.userNotFound.rawValue:
                    // Scenario A: Nonexistent email. Fail immediately with NO lockout modification.
                    self.errorMessage = "Invalid credentials. Please check your email and password."
                    
                case AuthErrorCode.wrongPassword.rawValue,
                     AuthErrorCode.invalidCredential.rawValue:
                    // Valid email + wrong password, OR the enumeration-protection
                    // fallback code Firebase returns when that setting is enabled.
                    // Either way this is a real bad-credential attempt: count it,
                    // and lock the account once it crosses the threshold.
                    if lockoutGuard.registerFailure(for: normalizedEmail) {
                        self.isAccountLocked = true
                        self.errorMessage = "Account locked after 5 failed attempts. Please try again in 15 minutes."
                    } else {
                        self.errorMessage = "Invalid credentials. Please check your email and password."
                    }

                default:
                    // Catch-all general system/network level faults
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    /// Handles registration constraints validation with isolated rule logic processing
    func performRegistration() async {
        // Clear screen error records prior to triggering pipeline
        await MainActor.run {
            self.hasAuthenticationError = false
            self.errorMessage = ""
            self.isLoading = true
        }
        
        // Isolate Rule Check 1: Client-side String Character Length Validation
        if userPassword.count < 6 {
            await MainActor.run {
                self.isLoading = false
                self.hasAuthenticationError = true
                self.errorMessage = "Password must be at least 6 characters long."
            }
            return
        }
        
        // Server-side Database Duplicate Verification
        do {
            let alreadyHasUsers = (try? await userRepository.hasAnyUsers()) ?? true
            let assignedRole: UserRole = alreadyHasUsers ? .interviewer : .admin

            let result = try await Auth.auth().createUser(withEmail: emailAddress, password: userPassword)

            // Persist the profile so role + name survive beyond the Auth record.
            let profile = UserProfile(
                userId: result.user.uid,
                fullName: fullName.trimmingCharacters(in: .whitespacesAndNewlines),
                emailAddress: emailAddress.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                role: assignedRole,
                isActive: true
            )
            try await userRepository.saveProfile(profile)

            await auditLogger.log(
                .userRegistered,
                actorId: profile.userId,
                actorRole: profile.role.rawValue,
                targetType: "user",
                targetId: profile.userId,
                details: profile.emailAddress
            )

            await MainActor.run {
                self.isLoading = false
                self.hasSuccessfullyRegistered = true
            }
        } catch {
            let registrationError = error as NSError
            
            await MainActor.run {
                self.isLoading = false
                self.hasAuthenticationError = true
                
                if registrationError.code == AuthErrorCode.emailAlreadyInUse.rawValue {
                    self.errorMessage = "This email address is already registered."
                } else {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Sends a Firebase password-reset email to the address in the email field.
    /// Shows a neutral confirmation regardless of whether the account exists, to
    /// avoid leaking which emails are registered (user-enumeration protection).
    func sendPasswordReset() async {
        let normalizedEmail = emailAddress.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !normalizedEmail.isEmpty else {
            await MainActor.run {
                self.hasAuthenticationError = true
                self.errorMessage = "Enter your email address above first, then tap Forgot?."
            }
            return
        }

        await MainActor.run {
            self.isLoading = true
            self.hasAuthenticationError = false
            self.errorMessage = ""
        }

        do {
            try await Auth.auth().sendPasswordReset(withEmail: normalizedEmail)
        } catch {
            // Surface a malformed address; everything else (including userNotFound)
            // falls through to the same neutral confirmation below.
            if (error as NSError).code == AuthErrorCode.invalidEmail.rawValue {
                await MainActor.run {
                    self.isLoading = false
                    self.hasAuthenticationError = true
                    self.errorMessage = "That doesn't look like a valid email address."
                }
                return
            }
        }

        await auditLogger.log(
            .passwordResetRequested,
            actorId: normalizedEmail,
            targetType: "user",
            targetId: normalizedEmail,
            details: normalizedEmail
        )

        await MainActor.run {
            self.isLoading = false
            self.passwordResetMessage = "If an account exists for \(normalizedEmail), a password reset link is on its way. Check your inbox and spam folder."
            self.showPasswordResetConfirmation = true
        }
    }
}

// MARK: - Login Lockout Policy

/// Per-email brute-force lockout bookkeeping, extracted from `AuthViewModel` so
/// the policy is pure, synchronous, and unit-testable without any Firebase calls.
/// `nonisolated` keeps it usable from any context (and off the project-wide
/// `MainActor` default). All time is injectable via `now:` so tests are deterministic.
nonisolated struct LoginLockoutGuard {
    /// Failed attempts before an account is locked.
    static let maxAttempts = 5
    /// How long a lock lasts once tripped.
    static let lockDuration: TimeInterval = 15 * 60

    private var failedAttempts: [String: Int] = [:]
    private var lockExpirations: [String: Date] = [:]

    init() {}

    /// If the email is currently locked, returns the whole minutes remaining
    /// (rounded up). If the lock has expired, it is cleared and `nil` is returned.
    mutating func activeLockMinutes(for email: String, now: Date = Date()) -> Int? {
        guard let expiry = lockExpirations[email] else { return nil }
        if now < expiry {
            return Int(ceil(expiry.timeIntervalSince(now) / 60.0))
        }
        // Lock has aged out of its window — reset access for this email.
        reset(for: email)
        return nil
    }

    /// Records one failed attempt for the email. Returns `true` if this attempt
    /// trips the lock (i.e. reaches `maxAttempts`).
    @discardableResult
    mutating func registerFailure(for email: String, now: Date = Date()) -> Bool {
        let attempts = (failedAttempts[email] ?? 0) + 1
        failedAttempts[email] = attempts
        if attempts >= Self.maxAttempts {
            lockExpirations[email] = now.addingTimeInterval(Self.lockDuration)
            return true
        }
        return false
    }

    /// Clears all failure/lock state for the email (called on successful login).
    mutating func reset(for email: String) {
        failedAttempts[email] = 0
        lockExpirations.removeValue(forKey: email)
    }

    /// Whether the email is locked right now (without mutating state).
    func isLocked(for email: String, now: Date = Date()) -> Bool {
        guard let expiry = lockExpirations[email] else { return false }
        return now < expiry
    }
}
