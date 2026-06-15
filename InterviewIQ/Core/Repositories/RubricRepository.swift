import Foundation
import FirebaseDatabase

// Read/write rubric questions at sessions/{sessionId}/rubricQuestions/{questionId}.
// Matches RubricRepository (C-20) in the class diagram. Field names mirror the
// reader in InterviewConductorService.fetchRubricQuestions so the live rating
// flow (UC-04) sees exactly what the editor (UC-03) writes.
nonisolated final class RubricRepository {
    private let db = Database.database().reference()

    func fetchQuestions(sessionId: String) async throws -> [RubricQuestion] {
        let snapshot = try await db
            .child("sessions").child(sessionId)
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

        return questions.sorted { $0.order < $1.order }
    }

    func saveQuestion(_ question: RubricQuestion, sessionId: String) async throws {
        let data: [String: Any] = [
            "id": question.id,
            "prompt": question.prompt,
            "maxScore": question.maxScore,
            "weight": question.weight,
            "order": question.order,
            "isRequired": question.isRequired
        ]
        try await db
            .child("sessions").child(sessionId)
            .child("rubricQuestions").child(question.id)
            .setValue(data)
    }

    func deleteQuestion(questionId: String, sessionId: String) async throws {
        try await db
            .child("sessions").child(sessionId)
            .child("rubricQuestions").child(questionId)
            .removeValue()
    }
}
