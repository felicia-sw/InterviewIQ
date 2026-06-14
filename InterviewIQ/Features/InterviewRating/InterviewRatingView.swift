import SwiftUI

// Root view for UC-04. Routes between the candidate list and the active rating form.
struct LiveRatingScreen: View {
    let sessionId: String
    let interviewerId: String

    @State private var viewModel = LiveRatingVM()

    var body: some View {
        // No NavigationStack here: this view is always pushed inside the
        // interviewer home's stack. Nesting stacks broke navigation (candidate
        // list wasn't reachable). It swaps candidate-list <-> rating in place.
        Group {
            if viewModel.isInRatingPhase {
                ratingScreen
            } else {
                CandidateListView(viewModel: viewModel)
            }
        }
        .task {
            viewModel.sessionId = sessionId
            viewModel.interviewerId = interviewerId
            await viewModel.loadCandidates()
        }
        // MARK: Alerts
        .alert("Something went wrong", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
        .alert("Submit Scores", isPresented: $viewModel.showSubmitConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Submit", role: .destructive) {
                Task { await viewModel.confirmSubmit() }
            }
        } message: {
            Text("Scores are final and cannot be edited after submission. Are you sure?")
        }
        // MARK: Banners
        .overlay(alignment: .top) {
            if viewModel.showSuccessBanner {
                StatusBannerView(message: "Scores submitted successfully!", color: .green) {
                    viewModel.showSuccessBanner = false
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            } else if viewModel.showOfflineBanner {
                StatusBannerView(message: "Saved offline — will sync when you're back online.", color: .orange) {
                    viewModel.showOfflineBanner = false
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut, value: viewModel.showSuccessBanner)
        .animation(.easeInOut, value: viewModel.showOfflineBanner)
    }

    // MARK: - Rating screen (Studio "Stage")

    private var ratingScreen: some View {
        VStack(spacing: 0) {
            progressHeader

            ScrollView {
                VStack(spacing: Studio.Spacing.md) {
                    if let question = viewModel.currentQuestion {
                        QuestionScoringView(
                            question: question,
                            questionNumber: viewModel.currentQuestionIndex + 1,
                            totalQuestions: viewModel.questions.count,
                            score: Binding(
                                get: { viewModel.currentScore?.score ?? 0 },
                                set: { newScore in
                                    viewModel.updateScore(
                                        score: newScore,
                                        notes: viewModel.currentScore?.notes ?? ""
                                    )
                                }
                            ),
                            notes: Binding(
                                get: { viewModel.currentScore?.notes ?? "" },
                                set: { newNotes in
                                    viewModel.updateScore(
                                        score: viewModel.currentScore?.score ?? 0,
                                        notes: newNotes
                                    )
                                }
                            )
                        )

                        questionDots
                            .padding(.bottom, Studio.Spacing.xs)
                    }
                }
                .padding(Studio.Spacing.md)
            }
            .scrollContentBackground(.hidden)

            navigationBar
        }
        .navigationTitle(viewModel.currentCandidate?.name ?? "Interview")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    Task { await viewModel.cancelInterview() }
                }
                .disabled(viewModel.isSubmitting)
            }
        }
        .studioStage()
    }

    // MARK: - Progress header

    private var progressHeader: some View {
        VStack(spacing: Studio.Spacing.xs) {
            HStack {
                Text("Question \(viewModel.currentQuestionIndex + 1) of \(viewModel.questions.count)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Text("\(viewModel.answeredCount) / \(viewModel.questions.count) scored")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(viewModel.allAnswered ? Studio.Palette.scoreHigh : .white.opacity(0.85))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.12))
                    Capsule()
                        .fill(viewModel.allAnswered
                              ? AnyShapeStyle(Studio.Palette.scoreHigh)
                              : AnyShapeStyle(Studio.auroraGradient))
                        .frame(width: geo.size.width * progressFraction)
                }
            }
            .frame(height: 6)
            .animation(.smooth, value: viewModel.answeredCount)
        }
        .padding(.horizontal, Studio.Spacing.md)
        .padding(.vertical, Studio.Spacing.sm)
        .background(.ultraThinMaterial)
    }

    private var progressFraction: CGFloat {
        let total = max(viewModel.questions.count, 1)
        return CGFloat(viewModel.answeredCount) / CGFloat(total)
    }

    // MARK: - Question dot indicators

    private var questionDots: some View {
        HStack(spacing: Studio.Spacing.xs) {
            // Array(enumerated()) snapshots questions into a copy so the body
            // never subscripts the live viewModel.questions — prevents a crash
            // when questions is reassigned from a background thread between the
            // ForEach range capture and the body evaluation.
            ForEach(Array(viewModel.questions.enumerated()), id: \.element.id) { index, question in
                let answered = viewModel.scores[question.id]?.isAnswered == true
                let isCurrent = index == viewModel.currentQuestionIndex
                Capsule()
                    .fill(isCurrent
                          ? AnyShapeStyle(Studio.auroraGradient)
                          : (answered
                             ? AnyShapeStyle(Studio.Palette.scoreHigh)
                             : AnyShapeStyle(Color.white.opacity(0.2))))
                    .frame(width: isCurrent ? 22 : 7, height: 7)
                    .onTapGesture { viewModel.jumpToQuestion(at: index) }
                    .animation(.snappy(duration: 0.2), value: viewModel.currentQuestionIndex)
            }
        }
    }

    // MARK: - Navigation bar

    private var navigationBar: some View {
        HStack(spacing: Studio.Spacing.sm) {
            Button {
                viewModel.goToPreviousQuestion()
            } label: {
                Label("Previous", systemImage: "chevron.left")
            }
            .buttonStyle(StageSecondaryButtonStyle())
            .disabled(viewModel.isFirstQuestion || viewModel.isSubmitting)

            if viewModel.isLastQuestion {
                Button {
                    viewModel.requestSubmit()
                } label: {
                    if viewModel.isSubmitting {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    } else {
                        Label("Submit", systemImage: "checkmark.seal.fill")
                    }
                }
                .buttonStyle(StagePrimaryButtonStyle(tint: viewModel.allAnswered ? Studio.Palette.scoreHigh : nil))
                .disabled(!viewModel.allAnswered || viewModel.isSubmitting)
            } else {
                Button {
                    viewModel.goToNextQuestion()
                } label: {
                    Label("Next", systemImage: "chevron.right")
                }
                .buttonStyle(StagePrimaryButtonStyle())
                .disabled(viewModel.isSubmitting)
            }
        }
        .padding(Studio.Spacing.md)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Status banner

private struct StatusBannerView: View {
    let message: String
    let color: Color
    let onDismiss: () -> Void

    var body: some View {
        Text(message)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(color.gradient)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    onDismiss()
                }
            }
    }
}
