import Foundation

// Score, typed notes, and auto-transcript for one rubric question during an interview.
struct QuestionScore: Identifiable, Codable, Hashable {
    let id: String
    let questionId: String
    var score: Int        // 1...maxScore; 0 means not yet answered
    var notes: String     // interviewer's deliberate, typed comment
    var transcript: String // auto speech-to-text of what was said (kept separate from notes)

    init(
        id: String = UUID().uuidString,
        questionId: String,
        score: Int = 0,
        notes: String = "",
        transcript: String = ""
    ) {
        self.id = id
        self.questionId = questionId
        self.score = score
        self.notes = notes
        self.transcript = transcript
    }

    // Tolerant decoding: records saved locally before `transcript` (and even
    // `notes`) existed still load — missing fields default to empty rather than
    // failing the whole decode and dropping an interviewer's in-progress work.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id         = try c.decode(String.self, forKey: .id)
        questionId = try c.decode(String.self, forKey: .questionId)
        score      = try c.decode(Int.self, forKey: .score)
        notes      = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        transcript = try c.decodeIfPresent(String.self, forKey: .transcript) ?? ""
    }

    var isAnswered: Bool { score > 0 }
}
