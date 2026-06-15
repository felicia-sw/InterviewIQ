import SwiftUI

// Single-question scoring card shown during UC-04 rating — Studio style: a
// clean white card on the grouped canvas with one-tap score pills that fill
// with the accent gradient on selection. Notes are deferred behind a chip to
// keep the surface glanceable while the interviewer is talking to the candidate.
struct QuestionScoringView: View {
    let question: RubricQuestion
    let questionNumber: Int
    let totalQuestions: Int
    @Binding var score: Int
    @Binding var notes: String
    @Binding var transcript: String

    @State private var showNotes = false

    // Live dictation (Speech framework) feeds the separate Transcript field.
    // `transcriptBase` is whatever was already captured when dictation (re)starts,
    // so recognized speech is appended rather than replacing it.
    @State private var dictation = SpeechDictationService()
    @State private var transcriptBase = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Studio.Spacing.lg) {
            questionHeader
            scoreSection
            transcriptSection
            notesSection
        }
        .studioCard(radius: Studio.Radius.hero, padding: Studio.Spacing.lg)
    }

    // MARK: - Question header

    private var questionHeader: some View {
        VStack(alignment: .leading, spacing: Studio.Spacing.sm) {
            HStack {
                Text("Q\(questionNumber) of \(totalQuestions)")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Studio.Palette.fill, in: Capsule())

                Spacer()

                Text("Max \(question.maxScore) pts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(question.prompt)
                .font(.title2)
                .fontWeight(.semibold)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Score input (one-tap pills)

    private var scoreSection: some View {
        VStack(alignment: .leading, spacing: Studio.Spacing.sm) {
            HStack {
                Text("Score")
                    .font(.subheadline).fontWeight(.medium)
                Spacer()
                if score > 0 {
                    Text("\(score) / \(question.maxScore)")
                        .font(.subheadline).fontWeight(.semibold)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .foregroundStyle(Studio.Palette.accent)
                } else {
                    Text("Not scored")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            ScoreButtonRow(score: $score, maxScore: question.maxScore)
        }
    }

    // MARK: - Notes (deferred)

    // MARK: - Transcript (auto speech-to-text, separate from notes)

    private var transcriptSection: some View {
        VStack(alignment: .leading, spacing: Studio.Spacing.sm) {
            HStack {
                Label("Transcript", systemImage: "waveform")
                    .font(.subheadline).fontWeight(.medium)
                    .foregroundStyle(.secondary)
                Spacer()
                dictationButton
            }

            if transcript.isEmpty && !dictation.isRecording {
                Text("Tap the mic to dictate what's said — captured separately from your notes.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                TextField("Spoken answer transcript…", text: $transcript, axis: .vertical)
                    .lineLimit(2...8)
                    .padding(Studio.Spacing.sm)
                    .background(Studio.Palette.fill,
                                in: RoundedRectangle(cornerRadius: Studio.Radius.chip, style: .continuous))
            }

            if dictation.isRecording {
                Label("Listening… tap the mic to stop", systemImage: "waveform")
                    .font(.caption).foregroundStyle(Studio.Palette.accent)
                    .symbolEffect(.variableColor.iterative, isActive: true)
            } else if let error = dictation.errorMessage {
                Text(error).font(.caption).foregroundStyle(Studio.Palette.scoreLow)
            }
        }
        .onChange(of: dictation.transcript) { _, spoken in
            guard dictation.isRecording else { return }
            let base = transcriptBase.trimmingCharacters(in: .whitespacesAndNewlines)
            transcript = base.isEmpty ? spoken : base + " " + spoken
        }
    }

    // Mic toggle for the transcript field.
    private var dictationButton: some View {
        Button {
            Task {
                if dictation.isRecording { dictation.stop() } else { await startDictation() }
            }
        } label: {
            Image(systemName: dictation.isRecording ? "mic.fill" : "mic")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(dictation.isRecording ? .white : Studio.Palette.accent)
                .frame(width: 34, height: 34)
                .background {
                    Circle().fill(dictation.isRecording
                                  ? AnyShapeStyle(Studio.accentGradient)
                                  : AnyShapeStyle(Studio.Palette.fill))
                }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact, trigger: dictation.isRecording)
        .accessibilityLabel(dictation.isRecording ? "Stop dictation" : "Start dictation")
    }

    private func startDictation() async {
        transcriptBase = transcript
        await dictation.start()
    }

    // MARK: - Notes (typed, deferred)

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: Studio.Spacing.sm) {
            if showNotes || !notes.isEmpty {
                Text("Notes")
                    .font(.subheadline).fontWeight(.medium)

                TextField("Add a comment about this answer…", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
                    .padding(Studio.Spacing.sm)
                    .background(Studio.Palette.fill,
                                in: RoundedRectangle(cornerRadius: Studio.Radius.chip, style: .continuous))
            } else {
                Button {
                    withAnimation(.snappy) { showNotes = true }
                } label: {
                    Label("Add note", systemImage: "plus")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Studio.Palette.accent)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Score button row

// One-tap score pills (1…maxScore). The selected pill fills with the accent
// gradient + a soft glow and fires a selection haptic. Scrolls when maxScore
// is large.
struct ScoreButtonRow: View {
    @Binding var score: Int
    let maxScore: Int

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Studio.Spacing.sm) {
                ForEach(1...maxScore, id: \.self) { value in
                    let isSelected = score == value
                    Button {
                        score = value
                    } label: {
                        Text("\(value)")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .frame(width: 52, height: 52)
                            .foregroundStyle(isSelected ? .white : .primary)
                            .background {
                                let shape = RoundedRectangle(cornerRadius: Studio.Radius.chip, style: .continuous)
                                if isSelected {
                                    shape.fill(Studio.accentGradient)
                                } else {
                                    shape.fill(Studio.Palette.fill)
                                }
                            }
                            .shadow(color: Studio.Palette.accent.opacity(isSelected ? 0.35 : 0),
                                    radius: 10, y: 2)
                            .scaleEffect(isSelected ? 1.06 : 1)
                    }
                    .buttonStyle(.plain)
                    .animation(.snappy(duration: 0.22), value: score)
                }
            }
            .padding(.vertical, Studio.Spacing.xs)
            .padding(.horizontal, 2)
        }
        .sensoryFeedback(.selection, trigger: score)
    }
}

// MARK: - Preview (no Firebase required)

private struct ScoringPreviewHost: View {
    @State private var score = 4
    @State private var notes = ""
    @State private var transcript = ""

    var body: some View {
        ScrollView {
            QuestionScoringView(
                question: RubricQuestion(
                    prompt: "Describe a time you resolved a conflict within a team and what you learned from it.",
                    maxScore: 5
                ),
                questionNumber: 3,
                totalQuestions: 8,
                score: $score,
                notes: $notes,
                transcript: $transcript
            )
            .padding()
        }
        .background(Studio.Palette.canvas)
    }
}

#Preview("Live Scoring · Card") { ScoringPreviewHost() }
