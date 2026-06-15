import Foundation

// LiveRatingVM (C-13): coordinates candidate locking, question-by-question
// scoring, offline persistence, and final submission for UC-04.
@Observable
final class LiveRatingVM {

    // MARK: - Session context (set by the parent view)
    var sessionId: String = ""
    var interviewerId: String = ""

    // MARK: - Candidate list phase
    var candidates: [Candidate] = []

    // MARK: - Rating phase
    var currentCandidate: Candidate?
    var questions: [RubricQuestion] = []
    var scores: [String: QuestionScore] = [:]   // questionId → QuestionScore
    var currentQuestionIndex: Int = 0

    // MARK: - UI state
    var isLoading: Bool = false
    var isSubmitting: Bool = false
    var errorMessage: String = ""
    var showError: Bool = false
    var showSubmitConfirmation: Bool = false
    var showSuccessBanner: Bool = false
    var showOfflineBanner: Bool = false

    // MARK: - Services
    private let conductor = InterviewConductorService()
    private let scoreRepo = ScoreRepository()
    private let candidateRepo = CandidateRepository()
    let syncManager = OfflineSyncManager()    // internal: LiveRatingScreen reads isOnline

    // MARK: - Computed helpers

    var isInRatingPhase: Bool { currentCandidate != nil }

    var currentQuestion: RubricQuestion? {
        guard questions.indices.contains(currentQuestionIndex) else { return nil }
        return questions[currentQuestionIndex]
    }

    var currentScore: QuestionScore? {
        guard let q = currentQuestion else { return nil }
        return scores[q.id]
    }

    var answeredCount: Int {
        questions.filter { scores[$0.id]?.isAnswered == true }.count
    }

    var allAnswered: Bool { answeredCount == questions.count && !questions.isEmpty }
    var isFirstQuestion: Bool { currentQuestionIndex == 0 }
    var isLastQuestion: Bool { currentQuestionIndex == questions.count - 1 }

    func candidateStatus(for candidate: Candidate) -> String {
        guard let saved = scoreRepo.loadLocalScore(candidateId: candidate.id) else {
            return "Not Started"
        }
        return saved.status == "submitted" ? "Completed" : "In Progress"
    }

    // MARK: - Candidate list

    func loadCandidates() async {
        isLoading = true
        defer { isLoading = false }
        do {
            candidates = try await candidateRepo.fetchCandidates(sessionId: sessionId)
        } catch {
            displayError("Failed to load candidates: \(error.localizedDescription)")
        }
    }

    // MARK: - Rating phase entry

    func startInterview(with candidate: Candidate) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let acquired = try await conductor.lockCandidate(
                candidateId: candidate.id,
                interviewerId: interviewerId,
                sessionId: sessionId
            )
            guard acquired else {
                displayError("\(candidate.name) is currently being interviewed by another panelist.")
                return
            }

            questions = try await conductor.fetchRubricQuestions(sessionId: sessionId)
            currentCandidate = candidate
            currentQuestionIndex = 0
            scores = [:]

            // Restore any locally saved in-progress scores
            if let saved = scoreRepo.loadLocalScore(candidateId: candidate.id),
               saved.status != "submitted" {
                for qs in saved.questionScores {
                    scores[qs.questionId] = qs
                }
            }
        } catch {
            displayError("Failed to start interview: \(error.localizedDescription)")
        }
    }

    // MARK: - Scoring

    func updateScore(score: Int, notes: String, transcript: String) {
        guard let q = currentQuestion, let candidate = currentCandidate else { return }
        // Keep 0 as "unanswered" so dictating/typing before scoring doesn't
        // silently mark a question as scored 1.
        let clamped = score <= 0 ? 0 : min(score, q.maxScore)
        scores[q.id] = QuestionScore(questionId: q.id, score: clamped, notes: notes, transcript: transcript)
        saveLocally(for: candidate)
    }

    func goToNextQuestion() {
        guard !isLastQuestion else { return }
        currentQuestionIndex += 1
    }

    func goToPreviousQuestion() {
        guard !isFirstQuestion else { return }
        currentQuestionIndex -= 1
    }

    func jumpToQuestion(at index: Int) {
        guard questions.indices.contains(index) else { return }
        currentQuestionIndex = index
    }

    // MARK: - Submission

    func requestSubmit() {
        let missing = conductor.unansweredQuestions(in: questions, scores: scores)
        if missing.isEmpty {
            showSubmitConfirmation = true
        } else {
            displayError("Please score all \(missing.count) remaining question(s) before submitting.")
        }
    }

    func confirmSubmit() async {
        guard let candidate = currentCandidate else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        let total = conductor.calculateTotalScore(questions: questions, scores: scores)
        var record = ScoreRecord(
            candidateId: candidate.id,
            interviewerId: interviewerId,
            sessionId: sessionId
        )
        record.questionScores = Array(scores.values)
        record.totalScore = total
        record.status = "submitted"
        record.syncStatus = .pending
        record.isImmutable = true
        record.submittedAt = Date()
        record.lockedAt = Date()

        // Enqueue: saves locally and syncs immediately if online
        syncManager.enqueue(record)

        // Release the candidate lock
        try? await conductor.releaseLock(candidateId: candidate.id, sessionId: sessionId)

        if syncManager.isOnline {
            showSuccessBanner = true
        } else {
            showOfflineBanner = true
        }

        resetRatingPhase()
    }

    func cancelInterview() async {
        guard let candidate = currentCandidate else { return }
        try? await conductor.releaseLock(candidateId: candidate.id, sessionId: sessionId)
        resetRatingPhase()
    }

    // MARK: - Private helpers

    private func saveLocally(for candidate: Candidate) {
        var record = ScoreRecord(
            candidateId: candidate.id,
            interviewerId: interviewerId,
            sessionId: sessionId
        )
        record.questionScores = Array(scores.values)
        scoreRepo.saveLocally(record)
    }

    private func resetRatingPhase() {
        currentCandidate = nil
        questions = []
        scores = [:]
        currentQuestionIndex = 0
    }

    private func displayError(_ message: String) {
        errorMessage = message
        showError = true
    }
}
