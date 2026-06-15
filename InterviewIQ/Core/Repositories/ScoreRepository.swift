import Foundation
import FirebaseDatabase

// Handles local persistence (UserDefaults) and remote Realtime Database writes for ScoreRecords.
// Offline-first: scores are always saved locally before any network operation (NFR-07).
nonisolated final class ScoreRepository {
    private let db = Database.database().reference()
    private let localKey = "pending_score_records"

    // MARK: - Local (offline-first)

    func saveLocally(_ record: ScoreRecord) {
        var pending = loadAllPendingLocal()
        pending[record.candidateId] = record
        persist(pending)
    }

    func loadLocalScore(candidateId: String) -> ScoreRecord? {
        loadAllPendingLocal()[candidateId]
    }

    func loadAllPending() -> [ScoreRecord] {
        Array(loadAllPendingLocal().values).filter { $0.syncStatus == .pending }
    }

    func removeLocalRecord(candidateId: String) {
        var pending = loadAllPendingLocal()
        pending.removeValue(forKey: candidateId)
        persist(pending)
    }

    // MARK: - Remote (Realtime Database)

    func submit(_ record: ScoreRecord) async throws {
        let ref = db
            .child("sessions")
            .child(record.sessionId)
            .child("scoreRecords")
            .child(record.candidateId)

        let data = try encodeScoreRecord(record)
        try await ref.setValue(data)
    }

    func markAsImmutable(candidateId: String, sessionId: String) async throws {
        let ref = db
            .child("sessions")
            .child(sessionId)
            .child("scoreRecords")
            .child(candidateId)

        try await ref.updateChildValues([
            "isImmutable": true,
            "lockedAt": ServerValue.timestamp(),
            "status": "submitted"
        ])
    }

    func markAsSynced(candidateId: String, sessionId: String) async throws {
        let ref = db
            .child("sessions")
            .child(sessionId)
            .child("scoreRecords")
            .child(candidateId)

        try await ref.updateChildValues(["syncStatus": SyncStatus.synced.rawValue])
    }

    // True if any candidate in the session has a submitted score record.
    // Used to protect a session from deletion once scoring has started (FR-04).
    func hasSubmittedScores(sessionId: String) async throws -> Bool {
        let snapshot = try await db
            .child("sessions")
            .child(sessionId)
            .child("scoreRecords")
            .getData()

        guard let dict = snapshot.value as? [String: Any] else { return false }

        return dict.values.contains { value in
            guard let entry = value as? [String: Any] else { return false }
            let status = entry["status"] as? String
            let isImmutable = entry["isImmutable"] as? Bool ?? false
            return status == "submitted" || isImmutable
        }
    }

    // MARK: - Private

    private func loadAllPendingLocal() -> [String: ScoreRecord] {
        guard
            let data = UserDefaults.standard.data(forKey: localKey),
            let records = try? JSONDecoder().decode([String: ScoreRecord].self, from: data)
        else { return [:] }
        return records
    }

    private func persist(_ records: [String: ScoreRecord]) {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: localKey)
        }
    }

    private func encodeScoreRecord(_ record: ScoreRecord) throws -> [String: Any] {
        let questionScores: [[String: Any]] = record.questionScores.map { qs in
            [
                "id": qs.id,
                "questionId": qs.questionId,
                "score": qs.score,
                "notes": qs.notes
            ]
        }

        var data: [String: Any] = [
            "id": record.id,
            "candidateId": record.candidateId,
            "interviewerId": record.interviewerId,
            "sessionId": record.sessionId,
            "totalScore": record.totalScore,
            "notes": record.notes,
            "status": record.status,
            "syncStatus": record.syncStatus.rawValue,
            "isImmutable": record.isImmutable,
            "questionScores": questionScores
        ]

        if let submittedAt = record.submittedAt {
            data["submittedAt"] = submittedAt.timeIntervalSince1970
        }
        if let lockedAt = record.lockedAt {
            data["lockedAt"] = lockedAt.timeIntervalSince1970
        }

        return data
    }
}
