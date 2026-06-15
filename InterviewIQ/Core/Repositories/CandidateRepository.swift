import Foundation
import FirebaseDatabase

// Reads candidate records for a given session from Realtime Database.
// Session Management is responsible for writing candidates to
// sessions/{sessionId}/candidates/{candidateId} when creating a session.
nonisolated final class CandidateRepository {
    private let db = Database.database().reference()

    func fetchCandidates(sessionId: String) async throws -> [Candidate] {
        let snapshot = try await db
            .child("sessions")
            .child(sessionId)
            .child("candidates")
            .getData()

        guard let dict = snapshot.value as? [String: Any] else { return [] }

        return dict.values.compactMap { value in
            guard let entry = value as? [String: Any],
                  let id = entry["id"] as? String,
                  let name = entry["name"] as? String,
                  let sessionId = entry["sessionId"] as? String
            else { return nil }
            return Candidate(id: id, name: name, sessionId: sessionId)
        }
    }
}
