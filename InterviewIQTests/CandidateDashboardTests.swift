//
//  CandidateDashboardTests.swift
//  InterviewIQTests
//
//  Created by Clarice Harijanto
//

import XCTest
@testable import InterviewIQ

// MARK: - Test Helpers

private func makeQuestion(
    id: String,
    maxScore: Int,
    weight: Double = 1.0,
    order: Int = 0
) -> RubricQuestion {
    RubricQuestion(id: id, prompt: "Q\(id)", maxScore: maxScore, weight: weight, order: order)
}

private func makeQuestionScore(questionId: String, score: Int) -> QuestionScore {
    QuestionScore(questionId: questionId, score: score)
}

private func makeRankedCandidate(
    id: String = UUID().uuidString,
    name: String,
    totalScore: Int,
    rank: Int,
    submittedAt: Date? = nil,
    notes: String = "",
    transcript: String = "",
    panelistCount: Int = 1,
    scoreSpread: Int = 0
) -> RankedCandidate {
    RankedCandidate(
        id: id,
        name: name,
        totalScore: totalScore,
        rank: rank,
        submittedAt: submittedAt,
        interviewerId: "interviewer-1",
        questionScores: [],
        notes: notes,
        transcript: transcript,
        panelistCount: panelistCount,
        scoreSpread: scoreSpread
    )
}


// MARK: - CandidateRankingService — calculateWeightedScore

final class CandidateRankingServiceTests: XCTestCase {

    let service = CandidateRankingService()

    // MARK: Basic formula

    func test_perfectScore_returns100() {
        let questions = [makeQuestion(id: "q1", maxScore: 10, weight: 1.0)]
        let scores    = [makeQuestionScore(questionId: "q1", score: 10)]

        let result = service.calculateWeightedScore(questions: questions, questionScores: scores)

        XCTAssertEqual(result, 100)
    }

    func test_zeroScore_returns0() {
        let questions = [makeQuestion(id: "q1", maxScore: 10, weight: 1.0)]
        // score == 0 means unanswered (isAnswered = false), so contributes nothing
        let scores    = [makeQuestionScore(questionId: "q1", score: 0)]

        let result = service.calculateWeightedScore(questions: questions, questionScores: scores)

        XCTAssertEqual(result, 0)
    }

    func test_halfScore_returns50() {
        let questions = [makeQuestion(id: "q1", maxScore: 10, weight: 1.0)]
        let scores    = [makeQuestionScore(questionId: "q1", score: 5)]

        let result = service.calculateWeightedScore(questions: questions, questionScores: scores)

        XCTAssertEqual(result, 50)
    }

    // MARK: Multiple questions, equal weight

    func test_multipleQuestions_equalWeight_averagesCorrectly() {
        // q1: 8/10, q2: 6/10 → (8+6)/(10+10) = 14/20 = 0.7 → 70
        let questions = [
            makeQuestion(id: "q1", maxScore: 10, weight: 1.0),
            makeQuestion(id: "q2", maxScore: 10, weight: 1.0)
        ]
        let scores = [
            makeQuestionScore(questionId: "q1", score: 8),
            makeQuestionScore(questionId: "q2", score: 6)
        ]

        let result = service.calculateWeightedScore(questions: questions, questionScores: scores)

        XCTAssertEqual(result, 70)
    }

    // MARK: Weighted questions

    func test_differentWeights_appliesWeightCorrectly() {
        // q1: weight 2, maxScore 10, score 10  → 10×2 = 20
        // q2: weight 1, maxScore 10, score 0   → unanswered → 0
        // maxPossible = 10×2 + 10×1 = 30
        // weightedSum = 20
        // result = Int(20/30 * 100) = Int(66.67) = 66
        let questions = [
            makeQuestion(id: "q1", maxScore: 10, weight: 2.0),
            makeQuestion(id: "q2", maxScore: 10, weight: 1.0)
        ]
        let scores = [
            makeQuestionScore(questionId: "q1", score: 10),
            makeQuestionScore(questionId: "q2", score: 0)  // unanswered
        ]

        let result = service.calculateWeightedScore(questions: questions, questionScores: scores)

        XCTAssertEqual(result, 66)
    }

    func test_higherWeightedQuestionDominatesScore() {
        // q1 (weight 3): 4/10 → 12 weighted points
        // q2 (weight 1): 10/10 → 10 weighted points
        // maxPossible = 30 + 10 = 40
        // weightedSum = 12 + 10 = 22
        // result = Int(22/40 * 100) = Int(55) = 55
        let questions = [
            makeQuestion(id: "q1", maxScore: 10, weight: 3.0),
            makeQuestion(id: "q2", maxScore: 10, weight: 1.0)
        ]
        let scores = [
            makeQuestionScore(questionId: "q1", score: 4),
            makeQuestionScore(questionId: "q2", score: 10)
        ]

        let result = service.calculateWeightedScore(questions: questions, questionScores: scores)

        XCTAssertEqual(result, 55)
    }

    // MARK: Different maxScores

    func test_differentMaxScores_scalesCorrectly() {
        // q1: maxScore 5, score 5, weight 1 → 5/5
        // q2: maxScore 20, score 10, weight 1 → 10/20
        // weightedSum = 5 + 10 = 15, maxPossible = 5 + 20 = 25
        // result = Int(15/25 * 100) = 60
        let questions = [
            makeQuestion(id: "q1", maxScore: 5,  weight: 1.0),
            makeQuestion(id: "q2", maxScore: 20, weight: 1.0)
        ]
        let scores = [
            makeQuestionScore(questionId: "q1", score: 5),
            makeQuestionScore(questionId: "q2", score: 10)
        ]

        let result = service.calculateWeightedScore(questions: questions, questionScores: scores)

        XCTAssertEqual(result, 60)
    }

    // MARK: Edge cases

    func test_emptyQuestions_returns0() {
        let result = service.calculateWeightedScore(questions: [], questionScores: [])
        XCTAssertEqual(result, 0)
    }

    func test_noScoresSubmitted_returns0() {
        let questions = [
            makeQuestion(id: "q1", maxScore: 10, weight: 1.0),
            makeQuestion(id: "q2", maxScore: 10, weight: 1.0)
        ]

        let result = service.calculateWeightedScore(questions: questions, questionScores: [])

        XCTAssertEqual(result, 0)
    }

    func test_partialAnswers_onlyCountsAnsweredQuestions() {
        // q1 answered (score 10), q2 unanswered (score 0)
        // weightedSum = 10, maxPossible = 20 → 50
        let questions = [
            makeQuestion(id: "q1", maxScore: 10, weight: 1.0),
            makeQuestion(id: "q2", maxScore: 10, weight: 1.0)
        ]
        let scores = [
            makeQuestionScore(questionId: "q1", score: 10),
            makeQuestionScore(questionId: "q2", score: 0)
        ]

        let result = service.calculateWeightedScore(questions: questions, questionScores: scores)

        XCTAssertEqual(result, 50)
    }

    func test_scoreForUnknownQuestion_isIgnored() {
        // "q-unknown" doesn't match any rubric question → should have no effect
        let questions = [makeQuestion(id: "q1", maxScore: 10, weight: 1.0)]
        let scores = [
            makeQuestionScore(questionId: "q1", score: 5),
            makeQuestionScore(questionId: "q-unknown", score: 10)
        ]

        let result = service.calculateWeightedScore(questions: questions, questionScores: scores)

        XCTAssertEqual(result, 50)
    }

    func test_resultIsAlwaysClamped0to100() {
        // Max achievable is 100 — this verifies no overflow
        let questions = [makeQuestion(id: "q1", maxScore: 10, weight: 1.0)]
        let scores    = [makeQuestionScore(questionId: "q1", score: 10)]

        let result = service.calculateWeightedScore(questions: questions, questionScores: scores)

        XCTAssertGreaterThanOrEqual(result, 0)
        XCTAssertLessThanOrEqual(result, 100)
    }
}

// MARK: - RankedCandidate — panel disagreement flag

final class RankedCandidateDisagreementTests: XCTestCase {

    func test_singlePanelist_neverFlagsDisagreement() {
        // Spread is meaningless with one panelist, even if it were non-zero.
        let c = makeRankedCandidate(name: "Alice", totalScore: 80, rank: 1,
                                    panelistCount: 1, scoreSpread: 40)
        XCTAssertFalse(c.hasDisagreement)
    }

    func test_multiPanelist_spreadBelowThreshold_noDisagreement() {
        // 14 < 15 → agreement.
        let c = makeRankedCandidate(name: "Alice", totalScore: 80, rank: 1,
                                    panelistCount: 3, scoreSpread: 14)
        XCTAssertFalse(c.hasDisagreement)
    }

    func test_multiPanelist_spreadAtThreshold_flagsDisagreement() {
        // 15 is the boundary and should flag.
        let c = makeRankedCandidate(name: "Alice", totalScore: 80, rank: 1,
                                    panelistCount: 2, scoreSpread: 15)
        XCTAssertTrue(c.hasDisagreement)
    }

    func test_multiPanelist_largeSpread_flagsDisagreement() {
        let c = makeRankedCandidate(name: "Alice", totalScore: 80, rank: 1,
                                    panelistCount: 4, scoreSpread: 42)
        XCTAssertTrue(c.hasDisagreement)
    }
}

// MARK: - DashboardComparisonVM — computed properties

final class DashboardComparisonVMTests: XCTestCase {

    // MARK: hasData

    func test_hasData_falseWhenEmpty() {
        let vm = DashboardComparisonVM()
        XCTAssertFalse(vm.hasData)
    }

    func test_hasData_trueWhenCandidatesLoaded() {
        let vm = DashboardComparisonVM()
        vm.rankedCandidates = [makeRankedCandidate(name: "Alice", totalScore: 80, rank: 1)]
        XCTAssertTrue(vm.hasData)
    }

    // MARK: topCandidate

    func test_topCandidate_nilWhenEmpty() {
        let vm = DashboardComparisonVM()
        XCTAssertNil(vm.topCandidate)
    }

    func test_topCandidate_isFirstInList() {
        let vm = DashboardComparisonVM()
        let alice = makeRankedCandidate(name: "Alice", totalScore: 90, rank: 1)
        let bob   = makeRankedCandidate(name: "Bob",   totalScore: 75, rank: 2)
        vm.rankedCandidates = [alice, bob]

        XCTAssertEqual(vm.topCandidate?.name, "Alice")
        XCTAssertEqual(vm.topCandidate?.totalScore, 90)
    }

    // MARK: averageScore

    func test_averageScore_zeroWhenEmpty() {
        let vm = DashboardComparisonVM()
        XCTAssertEqual(vm.averageScore, 0)
    }

    func test_averageScore_singleCandidate_equalsThatScore() {
        let vm = DashboardComparisonVM()
        vm.rankedCandidates = [makeRankedCandidate(name: "Alice", totalScore: 72, rank: 1)]
        XCTAssertEqual(vm.averageScore, 72)
    }

    func test_averageScore_multipleCandidates_computesCorrectly() {
        // (80 + 60 + 70) / 3 = 70
        let vm = DashboardComparisonVM()
        vm.rankedCandidates = [
            makeRankedCandidate(name: "Alice", totalScore: 80, rank: 1),
            makeRankedCandidate(name: "Bob",   totalScore: 60, rank: 2),
            makeRankedCandidate(name: "Carol", totalScore: 70, rank: 3)
        ]
        XCTAssertEqual(vm.averageScore, 70)
    }

    func test_averageScore_truncatesNotRounds() {
        // (90 + 91) / 2 = 90 (Int division truncates)
        let vm = DashboardComparisonVM()
        vm.rankedCandidates = [
            makeRankedCandidate(name: "Alice", totalScore: 90, rank: 1),
            makeRankedCandidate(name: "Bob",   totalScore: 91, rank: 2)
        ]
        XCTAssertEqual(vm.averageScore, 90)
    }

    // MARK: Initial state

    func test_initialState_isLoading_false() {
        let vm = DashboardComparisonVM()
        XCTAssertFalse(vm.isLoading)
    }

    func test_initialState_showError_false() {
        let vm = DashboardComparisonVM()
        XCTAssertFalse(vm.showError)
    }

    func test_initialState_sessionId_isEmpty() {
        let vm = DashboardComparisonVM()
        XCTAssertTrue(vm.sessionId.isEmpty)
    }

    func test_initialState_isExporting_false() {
        let vm = DashboardComparisonVM()
        XCTAssertFalse(vm.isExporting)
    }
}


// MARK: - ReportExportService — CSV generation

final class ReportExportServiceCSVTests: XCTestCase {

    let service = ReportExportService()

    private func csvLines(from url: URL) throws -> [String] {
        let content = try String(contentsOf: url, encoding: .utf8)
        return content.components(separatedBy: "\n")
    }

    // MARK: File creation

    func test_generateCSV_createsFileAtReturnedURL() throws {
        let candidates = [makeRankedCandidate(name: "Alice", totalScore: 85, rank: 1)]
        let url = try service.generateCSV(sessionTitle: "Test Session", candidates: candidates)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func test_generateCSV_fileHasCSVExtension() throws {
        let url = try service.generateCSV(sessionTitle: "Test Session", candidates: [])
        XCTAssertEqual(url.pathExtension, "csv")
    }

    func test_generateCSV_fileNameContainsSessionTitle() throws {
        let url = try service.generateCSV(sessionTitle: "Spring Hiring", candidates: [])
        XCTAssertTrue(url.lastPathComponent.contains("Spring_Hiring"))
    }

    // MARK: Content structure

    func test_generateCSV_containsHeaderRow() throws {
        let url = try service.generateCSV(sessionTitle: "S", candidates: [])
        let lines = try csvLines(from: url)
        XCTAssertTrue(lines.contains("Rank,Candidate Name,Total Score (%),Submitted At,Notes,Transcript"))
    }

    func test_generateCSV_includesTranscriptColumn() throws {
        let candidate = makeRankedCandidate(name: "Alice", totalScore: 80, rank: 1,
                                            transcript: "Discussed conflict resolution at length")
        let url = try service.generateCSV(sessionTitle: "S", candidates: [candidate])
        let content = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(content.contains("Discussed conflict resolution at length"))
    }

    func test_generateCSV_containsSessionTitle() throws {
        let url = try service.generateCSV(sessionTitle: "Q3 Interviews", candidates: [])
        let content = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(content.contains("Q3 Interviews"))
    }

    func test_generateCSV_containsBrandHeader() throws {
        let url = try service.generateCSV(sessionTitle: "S", candidates: [])
        let content = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(content.contains("InterviewIQ"))
    }

    // MARK: Data rows

    func test_generateCSV_oneCandidate_appearsInOutput() throws {
        let candidates = [makeRankedCandidate(name: "Alice Tan", totalScore: 88, rank: 1)]
        let url = try service.generateCSV(sessionTitle: "S", candidates: candidates)
        let content = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(content.contains("Alice Tan"))
        XCTAssertTrue(content.contains("88"))
        XCTAssertTrue(content.contains("1"))
    }

    func test_generateCSV_multipleCandidates_allAppearInOutput() throws {
        let candidates = [
            makeRankedCandidate(name: "Alice", totalScore: 90, rank: 1),
            makeRankedCandidate(name: "Bob",   totalScore: 75, rank: 2),
            makeRankedCandidate(name: "Carol", totalScore: 60, rank: 3)
        ]
        let url = try service.generateCSV(sessionTitle: "S", candidates: candidates)
        let content = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(content.contains("Alice"))
        XCTAssertTrue(content.contains("Bob"))
        XCTAssertTrue(content.contains("Carol"))
    }

    func test_generateCSV_rankOrderPreserved() throws {
        let candidates = [
            makeRankedCandidate(name: "Alice", totalScore: 90, rank: 1),
            makeRankedCandidate(name: "Bob",   totalScore: 75, rank: 2)
        ]
        let url = try service.generateCSV(sessionTitle: "S", candidates: candidates)
        let lines = try csvLines(from: url)
        let dataLines = lines.filter { $0.hasPrefix("1,") || $0.hasPrefix("2,") }
        XCTAssertEqual(dataLines.count, 2)
        XCTAssertTrue(dataLines[0].hasPrefix("1,"))
        XCTAssertTrue(dataLines[1].hasPrefix("2,"))
    }

    func test_generateCSV_emptyCandidates_stillWritesFile() throws {
        let url = try service.generateCSV(sessionTitle: "Empty Session", candidates: [])
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func test_generateCSV_emptyNotes_showsDash() throws {
        let candidate = makeRankedCandidate(name: "Alice", totalScore: 80, rank: 1, notes: "")
        let url = try service.generateCSV(sessionTitle: "S", candidates: [candidate])
        let content = try String(contentsOf: url, encoding: .utf8)
        // Notes field should contain the dash placeholder
        XCTAssertTrue(content.contains("—"))
    }

    func test_generateCSV_notesPresent_appearsInOutput() throws {
        let candidate = makeRankedCandidate(name: "Alice", totalScore: 80, rank: 1, notes: "Strong communicator")
        let url = try service.generateCSV(sessionTitle: "S", candidates: [candidate])
        let content = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(content.contains("Strong communicator"))
    }

    // MARK: CSV escaping

    func test_generateCSV_nameWithComma_isQuoted() throws {
        let candidate = makeRankedCandidate(name: "Smith, John", totalScore: 80, rank: 1)
        let url = try service.generateCSV(sessionTitle: "S", candidates: [candidate])
        let content = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(content.contains("\"Smith, John\""))
    }

    func test_generateCSV_nameWithQuote_isDoubleQuoted() throws {
        let candidate = makeRankedCandidate(name: "O\"Brien", totalScore: 80, rank: 1)
        let url = try service.generateCSV(sessionTitle: "S", candidates: [candidate])
        let content = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(content.contains("\"O\"\"Brien\""))
    }

    func test_generateCSV_plainName_isNotQuoted() throws {
        let candidate = makeRankedCandidate(name: "Alice Tan", totalScore: 80, rank: 1)
        let url = try service.generateCSV(sessionTitle: "S", candidates: [candidate])
        let content = try String(contentsOf: url, encoding: .utf8)
        // Plain name should appear without extra wrapping quotes
        XCTAssertTrue(content.contains("Alice Tan"))
        XCTAssertFalse(content.contains("\"Alice Tan\""))
    }
}

// MARK: - ReportExportService — PDF generation

final class ReportExportServicePDFTests: XCTestCase {

    let service = ReportExportService()

    // MARK: File creation

    func test_generatePDF_createsFileAtReturnedURL() throws {
        let candidates = [makeRankedCandidate(name: "Alice", totalScore: 85, rank: 1)]
        let url = try service.generatePDF(sessionTitle: "Test Session", sessionId: "s1", candidates: candidates)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func test_generatePDF_fileHasPDFExtension() throws {
        let url = try service.generatePDF(sessionTitle: "Test Session", sessionId: "s1", candidates: [])
        XCTAssertEqual(url.pathExtension, "pdf")
    }

    func test_generatePDF_fileNameContainsSessionTitle() throws {
        let url = try service.generatePDF(sessionTitle: "Winter Batch", sessionId: "s1", candidates: [])
        XCTAssertTrue(url.lastPathComponent.contains("Winter_Batch"))
    }

    func test_generatePDF_fileIsNotEmpty() throws {
        let candidates = [makeRankedCandidate(name: "Alice", totalScore: 85, rank: 1)]
        let url = try service.generatePDF(sessionTitle: "Test", sessionId: "s1", candidates: candidates)
        let data = try Data(contentsOf: url)
        XCTAssertGreaterThan(data.count, 0)
    }

    func test_generatePDF_fileStartsWithPDFMagicBytes() throws {
        let url = try service.generatePDF(sessionTitle: "Test", sessionId: "s1", candidates: [])
        let data = try Data(contentsOf: url)
        // PDF files always start with %PDF
        let header = String(data: data.prefix(4), encoding: .ascii)
        XCTAssertEqual(header, "%PDF")
    }

    func test_generatePDF_emptyCandidates_stillWritesValidFile() throws {
        let url = try service.generatePDF(sessionTitle: "Empty", sessionId: "s1", candidates: [])
        let data = try Data(contentsOf: url)
        XCTAssertGreaterThan(data.count, 0)
    }

    func test_generatePDF_manyCandidates_doesNotThrow() {
        // 50 candidates should paginate without crashing
        let candidates = (1...50).map {
            makeRankedCandidate(name: "Candidate \($0)", totalScore: 100 - $0, rank: $0)
        }
        XCTAssertNoThrow(
            try service.generatePDF(sessionTitle: "Large Session", sessionId: "s1", candidates: candidates)
        )
    }
}
