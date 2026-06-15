import Foundation
import FirebaseDatabase

// Business logic for UC-04: candidate locking, score validation,
// total-score calculation, and rubric/candidate fetching.
nonisolated final class InterviewConductorService {
    private let db = Database.database().reference()
    private let lockDuration: TimeInterval = 2 * 60 * 60  // 2 hours

    // MARK: - Data Fetching

    // Rubric questions are written for UC-03 at sessions/{id}/rubricQuestions
    func fetchRubricQuestions(sessionId: String) async throws -> [RubricQuestion] {
        let snapshot = try await db
            .child("sessions")
            .child(sessionId)
            .child("rubricQuestions")
            .getData()

        guard let dict = snapshot.value as? [String: Any] else { return [] }

        let questions: [RubricQuestion] = dict.values.compactMap { value in
            guard let entry = value as? [String: Any],
                  let id = entry["id"] as? String,
                  let prompt = entry["prompt"] as? String,
                  let maxScore = entry["maxScore"] as? Int,
                  let weight = entry["weight"] as? Double,
                  let order = entry["order"] as? Int,
                  let isRequired = entry["isRequired"] as? Bool
            else { return nil }
            return RubricQuestion(
                id: id,
                prompt: prompt,
                maxScore: maxScore,
                weight: weight,
                order: order,
                isRequired: isRequired
            )
        }

        // Replicate the original .order(by: "order") sort
        return questions.sorted { $0.order < $1.order }
    }

    // MARK: - Candidate Lock (1:1 rule per UC-04)

    // Returns true if the lock was acquired, false if another interviewer holds it.
    func lockCandidate(candidateId: String, interviewerId: String, sessionId: String) async throws -> Bool {
        let lockRef = db
            .child("sessions")
            .child(sessionId)
            .child("candidateLocks")
            .child(candidateId)

        let snapshot = try await lockRef.getData()

        // Deny if an active lock exists for a different interviewer
        if snapshot.exists(),
           let data = snapshot.value as? [String: Any],
           let isLocked = data["isLocked"] as? Bool, isLocked,
           let existingId = data["interviewerId"] as? String, existingId != interviewerId,
           let expiresTimestamp = data["expiresAt"] as? TimeInterval,
           Date(timeIntervalSince1970: expiresTimestamp) > Date() {
            return false
        }

        let now = Date()
        let lockData: [String: Any] = [
            "candidateId": candidateId,
            "interviewerId": interviewerId,
            "sessionId": sessionId,
            "lockedAt": now.timeIntervalSince1970,
            "expiresAt": now.addingTimeInterval(lockDuration).timeIntervalSince1970,
            "isLocked": true
        ]
        try await lockRef.setValue(lockData)
        return true
    }

    func releaseLock(candidateId: String, sessionId: String) async throws {
        try await db
            .child("sessions")
            .child(sessionId)
            .child("candidateLocks")
            .child(candidateId)
            .updateChildValues(["isLocked": false])
    }

    // MARK: - Validation & Calculation

    // Returns questions that have no score (score == 0) yet.
    func unansweredQuestions(in questions: [RubricQuestion], scores: [String: QuestionScore]) -> [RubricQuestion] {
        questions.filter { q in
            guard let s = scores[q.id] else { return true }
            return !s.isAnswered
        }
    }

    // Weighted percentage (0–100) across all questions.
    func calculateTotalScore(questions: [RubricQuestion], scores: [String: QuestionScore]) -> Int {
        var weightedSum = 0.0
        var maxPossible = 0.0

        for q in questions {
            maxPossible += Double(q.maxScore) * q.weight
            if let s = scores[q.id], s.isAnswered {
                weightedSum += Double(s.score) * q.weight
            }
        }

        guard maxPossible > 0 else { return 0 }
        return Int((weightedSum / maxPossible) * 100)
    }
}
