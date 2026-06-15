import Foundation
import FirebaseDatabase

// Single source of truth for user profile read/write at users/{uid}.
// Matches UserRepository (C-33) in the class diagram. Used by the auth flow
// to persist a profile on registration and to read the role for RBAC routing.
nonisolated final class UserRepository {
    private let db = Database.database().reference()

    // Writes the full profile (name, email, role, isActive) under users/{uid}.
    func saveProfile(_ profile: UserProfile) async throws {
        let data: [String: Any] = [
            "userId": profile.userId,
            "fullName": profile.fullName,
            "emailAddress": profile.emailAddress,
            "role": profile.role.rawValue,
            "isActive": profile.isActive
        ]
        try await db.child("users").child(profile.userId).setValue(data)
    }

    // Reads a profile by uid. Falls back to .interviewer / isActive=true when
    // legacy records (written before RBAC) are missing those fields, so older
    // accounts still resolve to a safe, least-privileged role.
    func fetchProfile(userId: String) async throws -> UserProfile? {
        let snapshot = try await db.child("users").child(userId).getData()

        guard let value = snapshot.value as? [String: Any],
              let name = value["fullName"] as? String,
              let email = value["emailAddress"] as? String
        else { return nil }

        let role = (value["role"] as? String).flatMap(UserRole.init(rawValue:)) ?? .interviewer
        let isActive = value["isActive"] as? Bool ?? true

        return UserProfile(
            userId: userId,
            fullName: name,
            emailAddress: email,
            role: role,
            isActive: isActive
        )
    }

    // All active interviewers, for the admin's per-session assignment list.
    // Mirrors fetchUsers() (C-33) but scoped to assignable accounts.
    func fetchInterviewers() async throws -> [UserProfile] {
        try await fetchAllUsers().filter { $0.role == .interviewer && $0.isActive }
    }

    // Every registered user, for the admin user-management screen (FR-10).
    func fetchAllUsers() async throws -> [UserProfile] {
        let snapshot = try await db.child("users").getData()

        guard let dict = snapshot.value as? [String: Any] else { return [] }

        return dict.compactMap { uid, value in
            guard let entry = value as? [String: Any],
                  let name = entry["fullName"] as? String,
                  let email = entry["emailAddress"] as? String
            else { return nil }

            let role = (entry["role"] as? String).flatMap(UserRole.init(rawValue:)) ?? .interviewer
            let isActive = entry["isActive"] as? Bool ?? true

            return UserProfile(
                userId: uid,
                fullName: name,
                emailAddress: email,
                role: role,
                isActive: isActive
            )
        }
        .sorted { $0.fullName.localizedCaseInsensitiveCompare($1.fullName) == .orderedAscending }
    }

    // Looks up a single active interviewer by email for per-session assignment.
    // Reads internally but returns only the one match, so the admin never sees a
    // roster of every interviewer's email (privacy).
    func findInterviewerByEmail(_ email: String) async throws -> UserProfile? {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return nil }
        let all = try await fetchAllUsers()
        return all.first {
            $0.emailAddress.lowercased() == normalized && $0.role == .interviewer && $0.isActive
        }
    }

    // True when no account exists yet — used to bootstrap the very first user
    // as Admin (so roles aren't self-selected at registration).
    func hasAnyUsers() async throws -> Bool {
        let snapshot = try await db.child("users").getData()
        return snapshot.exists() && (snapshot.value as? [String: Any])?.isEmpty == false
    }

    // Admin-only mutations. Update a single field rather than rewriting the whole
    // profile so concurrent edits to other fields aren't clobbered.
    func updateRole(userId: String, role: UserRole) async throws {
        try await db.child("users").child(userId).child("role").setValue(role.rawValue)
    }

    func setActive(userId: String, isActive: Bool) async throws {
        try await db.child("users").child(userId).child("isActive").setValue(isActive)
    }
}
