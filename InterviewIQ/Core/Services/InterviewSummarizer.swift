//
//  InterviewSummarizer.swift
//  InterviewIQ
//
//  On-device AI summary of a candidate's interview notes using Apple's
//  FoundationModels (Apple Intelligence). Runs entirely on-device — no API key,
//  no data leaves the phone — which fits InterviewIQ's offline-first, privacy
//  posture. Degrades gracefully where the model isn't available (older devices,
//  the Simulator, or Apple Intelligence turned off).
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

struct InterviewSummary {
    let text: String
    /// False when produced without the on-device model (caller can flag it).
    let isAIGenerated: Bool
}

@Observable
final class InterviewSummarizer {
    enum State: Equatable {
        case idle
        case working
        case unavailable(String)   // human-readable reason
    }

    private(set) var state: State = .idle

    // See [[interviewiq-mainactor-deinit-crash]] — synchronous deinit.
    nonisolated deinit {}

    /// Whether an on-device model is ready to use right now.
    var isModelAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return SystemLanguageModel.default.availability == .available
        }
        #endif
        return false
    }

    /// Summarizes combined interview notes. Returns nil if there's nothing to
    /// summarize or the model is unavailable (in which case `state` carries the
    /// reason for the UI to show).
    func summarize(notes: String) async -> InterviewSummary? {
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            state = .unavailable("There are no notes to summarize yet.")
            return nil
        }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let model = SystemLanguageModel.default
            switch model.availability {
            case .available:
                state = .working
                defer { state = .idle }
                do {
                    let session = LanguageModelSession(instructions: Self.instructions)
                    let response = try await session.respond(to: "Summarize these interview notes:\n\n\(trimmed)")
                    return InterviewSummary(text: response.content, isAIGenerated: true)
                } catch {
                    state = .unavailable("The on-device model couldn't generate a summary.")
                    return nil
                }
            case .unavailable(let reason):
                state = .unavailable(Self.describe(reason))
                return nil
            @unknown default:
                state = .unavailable("On-device AI isn't available on this device.")
                return nil
            }
        }
        #endif

        state = .unavailable("On-device AI summaries need iOS 26 with Apple Intelligence.")
        return nil
    }

    private static let instructions = """
    You summarize interview panel notes to help a hiring decision. Be concise and \
    neutral. In 2–3 sentences, capture the candidate's strengths, any concerns, and \
    the overall impression. Only use what is in the notes — never invent details.
    """

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private static func describe(_ reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible:
            return "This device doesn't support Apple Intelligence."
        case .appleIntelligenceNotEnabled:
            return "Turn on Apple Intelligence in Settings to use AI summaries."
        case .modelNotReady:
            return "The on-device model is still downloading. Try again shortly."
        @unknown default:
            return "On-device AI isn't available right now."
        }
    }
    #endif
}
