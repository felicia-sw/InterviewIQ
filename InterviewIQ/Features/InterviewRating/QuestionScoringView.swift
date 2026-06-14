import SwiftUI

// Single-question scoring card shown during UC-04 rating — Studio "Stage" style:
// a frosted glass card on the dark aurora backdrop, with one-tap score pills
// that "ignite" on selection. Notes are deferred behind a chip to keep the
// surface glanceable while the interviewer is talking to the candidate.
struct QuestionScoringView: View {
    let question: RubricQuestion
    let questionNumber: Int
    let totalQuestions: Int
    @Binding var score: Int
    @Binding var notes: String

    @State private var showNotes = false

    var body: some View {
        VStack(alignment: .leading, spacing: Studio.Spacing.lg) {
            questionHeader
            scoreSection
            notesSection
        }
        .padding(Studio.Spacing.lg)
        .background(.ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: Studio.Radius.hero, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Studio.Radius.hero, style: .continuous)
                .strokeBorder(.white.opacity(0.10))
        )
    }

    // MARK: - Question header

    private var questionHeader: some View {
        VStack(alignment: .leading, spacing: Studio.Spacing.sm) {
            HStack {
                Text("Q\(questionNumber) of \(totalQuestions)")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.10), in: Capsule())

                Spacer()

                Text("Max \(question.maxScore) pts")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }

            Text(question.prompt)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Score input (one-tap pills)

    private var scoreSection: some View {
        VStack(alignment: .leading, spacing: Studio.Spacing.sm) {
            HStack {
                Text("Score")
                    .font(.subheadline).fontWeight(.medium)
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                if score > 0 {
                    Text("\(score) / \(question.maxScore)")
                        .font(.subheadline).fontWeight(.semibold)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .foregroundStyle(.white)
                } else {
                    Text("Not scored")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            ScoreButtonRow(score: $score, maxScore: question.maxScore)
        }
    }

    // MARK: - Notes (deferred)

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: Studio.Spacing.sm) {
            if showNotes || !notes.isEmpty {
                Text("Notes")
                    .font(.subheadline).fontWeight(.medium)
                    .foregroundStyle(.white.opacity(0.8))

                TextField("Add a comment about this answer…", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
                    .foregroundStyle(.white)
                    .padding(Studio.Spacing.sm)
                    .background(.white.opacity(0.08),
                                in: RoundedRectangle(cornerRadius: Studio.Radius.chip, style: .continuous))
            } else {
                Button {
                    withAnimation(.snappy) { showNotes = true }
                } label: {
                    Label("Add note", systemImage: "plus")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Score button row

// One-tap score pills (1…maxScore). The selected pill ignites with the aurora
// gradient + a soft glow and a selection haptic. Scrolls when maxScore is large.
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
                            .foregroundStyle(isSelected ? .white : .white.opacity(0.85))
                            .background {
                                let shape = RoundedRectangle(cornerRadius: Studio.Radius.chip, style: .continuous)
                                if isSelected {
                                    shape.fill(Studio.auroraGradient)
                                } else {
                                    shape.fill(.ultraThinMaterial)
                                }
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: Studio.Radius.chip, style: .continuous)
                                    .strokeBorder(.white.opacity(isSelected ? 0 : 0.12))
                            )
                            .shadow(color: Studio.Palette.auroraViolet.opacity(isSelected ? 0.55 : 0),
                                    radius: 14, y: 2)
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

    var body: some View {
        ZStack {
            AuroraBackground()
            ScrollView {
                QuestionScoringView(
                    question: RubricQuestion(
                        prompt: "Describe a time you resolved a conflict within a team and what you learned from it.",
                        maxScore: 5
                    ),
                    questionNumber: 3,
                    totalQuestions: 8,
                    score: $score,
                    notes: $notes
                )
                .padding()
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview("Live Scoring · Stage") { ScoringPreviewHost() }
