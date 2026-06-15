//
//  CandidateRankingService.swift
//  InterviewIQ
//
//  Created by Clarice Harijanto
//

import Foundation
import FirebaseDatabase

// MARK: - Ranked Candidate Model

struct RankedCandidate: Identifiable {
    let id: String          // candidateId
    let name: String
    let totalScore: Int     // 0–100 weighted percentage, AVERAGED across panelists
    let rank: Int
    let submittedAt: Date?   // most recent panelist submission
    let interviewerId: String // retained for compatibility; "" for multi-panelist aggregates
    let questionScores: [QuestionScore] // per-question MEAN across panelists (drives the sparkline)
    let notes: String        // combined panelist typed notes
    let transcript: String   // combined panelist auto-transcripts (kept separate from notes)
    let panelistCount: Int   // how many panelists scored this candidate
    let scoreSpread: Int     // max − min of panelist totals (0 for a single panelist)

    // Flags candidates the panel disagrees on (≥15 percentage-point spread).
    var hasDisagreement: Bool { panelistCount > 1 && scoreSpread >= 15 }
}

// MARK: - Service

// CandidateRankingService (C-03): fetches score records and rubric for a session,
// computes weighted totals, and returns candidates sorted highest -> lowest.
// Tie-breaker: earlier submittedAt wins (lower rank number = better).
// `nonisolated` opts this data-layer service out of the project-wide
// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` default. It does pure data
// access (no UI state), so it doesn't belong on the main actor — and, more
// importantly, a MainActor-isolated deinit tears down via the Swift
// concurrency runtime (`swift_task_deinitOnExecutorImpl`), which double-frees
// under guard-malloc and crashes the dashboard's deinit. A nonisolated class
// gets a plain synchronous deinit, and its network fetch runs off the main
// thread.
nonisolated final class CandidateRankingService {
    private let db = Database.database().reference()

    // Returns a ranked list of candidates for a given session.
    // Candidates with no submitted score record are excluded.
    func fetchRankedCandidates(sessionId: String) async throws -> [RankedCandidate] {
        // 1. Fetch rubric questions (needed for weighted recalculation as source of truth)
        let questions = try await fetchRubricQuestions(sessionId: sessionId)

        // 2. Fetch all candidates so we can map ids → names
        let candidates = try await fetchCandidates(sessionId: sessionId)
        let candidateMap: [String: String] = Dictionary(
            uniqueKeysWithValues: candidates.map { ($0.id, $0.name) }
        )

        // 3. Fetch all submitted score records
        let scoreRecords = try await fetchSubmittedScoreRecords(sessionId: sessionId)

        // 4. Aggregate every panelist's submitted record per candidate (true panel:
        //    multiple interviewers can score the same candidate). One ranked entry
        //    per candidate — averaged score, plus a disagreement spread.
        let recordsByCandidate = Dictionary(grouping: scoreRecords, by: { $0.candidateId })

        let aggregated: [RankedCandidate] = recordsByCandidate.compactMap { candidateId, records in
            guard let name = candidateMap[candidateId] else { return nil }

            // Each panelist's weighted total, using the same formula as InterviewConductorService.
            let totals = records.map {
                calculateWeightedScore(questions: questions, questionScores: $0.questionScores)
            }
            guard !totals.isEmpty else { return nil }

            let average = totals.reduce(0, +) / totals.count
            let spread = (totals.max() ?? 0) - (totals.min() ?? 0)
            let latestSubmittedAt = records.compactMap { $0.submittedAt }.max()

            // Pull typed notes and auto-transcripts from each panelist's
            // per-question entries (the top-level record.notes is unused), keeping
            // the two streams separate end-to-end.
            let allQuestionScores = records.flatMap { $0.questionScores }
            let combinedNotes = allQuestionScores
                .map { $0.notes }
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .joined(separator: "\n")
            let combinedTranscript = allQuestionScores
                .map { $0.transcript }
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .joined(separator: "\n")

            return RankedCandidate(
                id: candidateId,
                name: name,
                totalScore: average,
                rank: 0, // assigned below after sorting
                submittedAt: latestSubmittedAt,
                interviewerId: records.count == 1 ? records[0].interviewerId : "",
                questionScores: meanQuestionScores(questions: questions, records: records),
                notes: combinedNotes,
                transcript: combinedTranscript,
                panelistCount: records.count,
                scoreSpread: spread
            )
        }

        // 5. Sort and assign rank numbers
        return sortCandidates(aggregated)
    }

    // Sorts candidates highest-score first (tie-break: earlier submittedAt wins)
    // and assigns 1-indexed rank numbers.
    func sortCandidates(_ candidates: [RankedCandidate]) -> [RankedCandidate] {
        var sorted = candidates
        sorted.sort {
            if $0.totalScore != $1.totalScore { return $0.totalScore > $1.totalScore }
            let lhs = $0.submittedAt ?? Date.distantFuture
            let rhs = $1.submittedAt ?? Date.distantFuture
            return lhs < rhs
        }
        return sorted.enumerated().map { index, candidate in
            RankedCandidate(
                id: candidate.id,
                name: candidate.name,
                totalScore: candidate.totalScore,
                rank: index + 1,
                submittedAt: candidate.submittedAt,
                interviewerId: candidate.interviewerId,
                questionScores: candidate.questionScores,
                notes: candidate.notes,
                transcript: candidate.transcript,
                panelistCount: candidate.panelistCount,
                scoreSpread: candidate.scoreSpread
            )
        }
    }

    // Per-question mean score across all panelists, in rubric order. Drives the
    // dashboard sparkline so it reflects the panel's consensus, not one rater.
    private func meanQuestionScores(questions: [RubricQuestion], records: [ScoreRecord]) -> [QuestionScore] {
        questions.compactMap { q in
            let scores = records.compactMap { record -> Int? in
                guard let qs = record.questionScores.first(where: { $0.questionId == q.id }),
                      qs.isAnswered else { return nil }
                return qs.score
            }
            guard !scores.isEmpty else { return nil }
            let mean = scores.reduce(0, +) / scores.count
            return QuestionScore(questionId: q.id, score: mean, notes: "")
        }
    }

    // MARK: - Weighted Score Formula
    // Σ(score × weight) / Σ(maxScore × weight) × 100  →  0–100 Int
    // Matches InterviewConductorService.calculateTotalScore exactly.

    func calculateWeightedScore(questions: [RubricQuestion], questionScores: [QuestionScore]) -> Int {
        guard !questions.isEmpty else { return 0 }
        let scoreMap = Dictionary(uniqueKeysWithValues: questionScores.map { ($0.questionId, $0) })
        var weightedSum = 0.0
        var maxPossible = 0.0
        for q in questions {
            maxPossible += Double(q.maxScore) * q.weight
            if let qs = scoreMap[q.id], qs.isAnswered {
                weightedSum += Double(qs.score) * q.weight
            }
        }
        guard maxPossible > 0 else { return 0 }
        return Int((weightedSum / maxPossible) * 100)
    }

    // MARK: - Private Fetchers

    private func fetchRubricQuestions(sessionId: String) async throws -> [RubricQuestion] {
        let snapshot = try await db
            .child("sessions").child(sessionId)
            .child("rubricQuestions")
            .getData()

        guard let dict = snapshot.value as? [String: Any] else { return [] }
        return dict.values.compactMap { value -> RubricQuestion? in
            guard let entry = value as? [String: Any],
                  let id = entry["id"] as? String,
                  let prompt = entry["prompt"] as? String,
                  let maxScore = entry["maxScore"] as? Int,
                  let weight = entry["weight"] as? Double,
                  let order = entry["order"] as? Int,
                  let isRequired = entry["isRequired"] as? Bool
            else { return nil }
            return RubricQuestion(id: id, prompt: prompt, maxScore: maxScore,
                                  weight: weight, order: order, isRequired: isRequired)
        }.sorted { $0.order < $1.order }
    }

    private func fetchCandidates(sessionId: String) async throws -> [Candidate] {
        let snapshot = try await db
            .child("sessions").child(sessionId)
            .child("candidates")
            .getData()

        guard let dict = snapshot.value as? [String: Any] else { return [] }
        return dict.values.compactMap { value -> Candidate? in
            guard let entry = value as? [String: Any],
                  let id = entry["id"] as? String,
                  let name = entry["name"] as? String,
                  let sessionId = entry["sessionId"] as? String
            else { return nil }
            return Candidate(id: id, name: name, sessionId: sessionId)
        }
    }

    private func fetchSubmittedScoreRecords(sessionId: String) async throws -> [ScoreRecord] {
        let snapshot = try await db
            .child("sessions").child(sessionId)
            .child("scoreRecords")
            .getData()

        guard let dict = snapshot.value as? [String: Any] else { return [] }
        return dict.values.compactMap { value -> ScoreRecord? in
            guard let entry = value as? [String: Any],
                  let id = entry["id"] as? String,
                  let candidateId = entry["candidateId"] as? String,
                  let interviewerId = entry["interviewerId"] as? String,
                  let sessionId = entry["sessionId"] as? String,
                  let status = entry["status"] as? String,
                  status == "submitted"           // only fully submitted records
            else { return nil }

            var record = ScoreRecord(
                id: id,
                candidateId: candidateId,
                interviewerId: interviewerId,
                sessionId: sessionId
            )
            record.totalScore = entry["totalScore"] as? Int ?? 0
            record.notes = entry["notes"] as? String ?? ""
            record.status = status
            record.isImmutable = entry["isImmutable"] as? Bool ?? false

            if let ts = entry["submittedAt"] as? TimeInterval {
                record.submittedAt = Date(timeIntervalSince1970: ts)
            }
            if let ts = entry["lockedAt"] as? TimeInterval {
                record.lockedAt = Date(timeIntervalSince1970: ts)
            }

            // Parse questionScores array
            if let qsArray = entry["questionScores"] as? [[String: Any]] {
                record.questionScores = qsArray.compactMap { qs -> QuestionScore? in
                    guard let qid = qs["id"] as? String,
                          let questionId = qs["questionId"] as? String,
                          let score = qs["score"] as? Int
                    else { return nil }
                    return QuestionScore(
                        id: qid,
                        questionId: questionId,
                        score: score,
                        notes: qs["notes"] as? String ?? "",
                        transcript: qs["transcript"] as? String ?? ""
                    )
                }
            }

            return record
        }
    }
}
