import Foundation
import FirebaseDatabase

nonisolated final class SessionRepository {
    private let db = Database.database().reference()

    func fetchSessions(adminId: String) async throws -> [Session] {
        let snapshot = try await db.child("sessions").getData()

        guard let dict = snapshot.value as? [String: Any] else { return [] }

        return dict.values.compactMap { value in
            guard let entry = value as? [String: Any],
                  let id = entry["id"] as? String,
                  let title = entry["title"] as? String,
                  let dateTimestamp = entry["date"] as? TimeInterval,
                  let entryAdminId = entry["adminId"] as? String,
                  entryAdminId == adminId
            else { return nil }

            let date = Date(timeIntervalSince1970: dateTimestamp)
            let interviewerIds = parseInterviewerIds(entry["interviewerIds"])
            return Session(id: id, title: title, date: date, adminId: entryAdminId, interviewerIds: interviewerIds)
        }
    }

    // Sessions an interviewer is assigned to (interviewerIds contains their uid).
    // Mirrors fetchSessions(adminId:) but filters on assignment instead of ownership.
    func fetchAssignedSessions(interviewerId: String) async throws -> [Session] {
        let snapshot = try await db.child("sessions").getData()

        guard let dict = snapshot.value as? [String: Any] else { return [] }

        return dict.values.compactMap { value in
            guard let entry = value as? [String: Any],
                  let id = entry["id"] as? String,
                  let title = entry["title"] as? String,
                  let dateTimestamp = entry["date"] as? TimeInterval,
                  let entryAdminId = entry["adminId"] as? String
            else { return nil }

            let interviewerIds = parseInterviewerIds(entry["interviewerIds"])
            guard interviewerIds.contains(interviewerId) else { return nil }

            let date = Date(timeIntervalSince1970: dateTimestamp)
            return Session(id: id, title: title, date: date, adminId: entryAdminId, interviewerIds: interviewerIds)
        }
    }

    func saveSession(_ session: Session) async throws {
        let data = encodeSession(session)
        try await db.child("sessions").child(session.id).setValue(data)
    }

    func updateSession(_ session: Session) async throws {
        // Re-read interviewerIds from Firebase and include them explicitly in the update.
        // updateChildValues on the session node causes Firebase RTDB to re-normalize any
        // array siblings (interviewerIds) from NSArray to an integer-keyed NSDictionary,
        // which breaks the subsequent `as? [String]` cast in fetchSessions. Writing the
        // ids back as part of this same call prevents the reformat.
        var data = encodeSession(session)
        let freshIds = try await fetchInterviewerIds(sessionId: session.id)
        if !freshIds.isEmpty {
            data["interviewerIds"] = freshIds
        }
        try await db.child("sessions").child(session.id).updateChildValues(data)
    }

    func fetchInterviewerIds(sessionId: String) async throws -> [String] {
        let snapshot = try await db.child("sessions").child(sessionId).child("interviewerIds").getData()
        return parseInterviewerIds(snapshot.value)
    }

    // Writes ONLY the interviewerIds child — never touches candidates, rubricQuestions,
    // scoreRecords, or any other session data. Use this for all panelist mutations so
    // updateSession (which encodes the full session) is never called for these operations.
    func updateInterviewerIds(sessionId: String, interviewerIds: [String]) async throws {
        let ref = db.child("sessions").child(sessionId).child("interviewerIds")
        if interviewerIds.isEmpty {
            try await ref.removeValue()
        } else {
            try await ref.setValue(interviewerIds)
        }
    }

    func deleteSession(sessionId: String) async throws {
        try await db.child("sessions").child(sessionId).removeValue()
    }

    func saveCandidate(_ candidate: Candidate, sessionId: String) async throws {
        let data: [String: Any] = [
            "id": candidate.id,
            "name": candidate.name,
            "sessionId": candidate.sessionId
        ]
        try await db
            .child("sessions").child(sessionId)
            .child("candidates").child(candidate.id)
            .setValue(data)
    }

    func deleteCandidate(candidateId: String, sessionId: String) async throws {
        try await db
            .child("sessions").child(sessionId)
            .child("candidates").child(candidateId)
            .removeValue()
    }

    // MARK: - Private

    // Firebase RTDB stores Swift arrays as sequential integer-keyed objects internally.
    // After a sibling updateChildValues call the SDK may return the node as NSDictionary
    // {"0": "uid1"} rather than NSArray, breaking a plain `as? [String]` cast. This
    // helper handles both representations.
    private func parseInterviewerIds(_ raw: Any?) -> [String] {
        if let arr = raw as? [String] { return arr }
        if let dict = raw as? [String: Any] {
            return dict
                .sorted { (Int($0.key) ?? 0) < (Int($1.key) ?? 0) }
                .compactMap { $0.value as? String }
        }
        return []
    }

    private func encodeSession(_ session: Session) -> [String: Any] {
        return [
            "id": session.id,
            "title": session.title,
            "date": session.date.timeIntervalSince1970,
            "adminId": session.adminId
            // interviewerIds is intentionally excluded — all mutations go through updateInterviewerIds
        ]
    }
}
