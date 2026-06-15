import Foundation
import SwiftUI

// MARK: - ViewModel

// CreateEditRubricVM (AGENTS.md Section 1): manages post-creation rubric editing
// for a session. Delegates all writes through SessionManagementService so
// lockRubricEdits() is always enforced before any mutation.
@Observable
final class CreateEditRubricVM {
    let session: Session

    var questionEntries: [RubricQuestionEntry] = []
    var isLoading: Bool = false
    var isSaving: Bool = false
    var isLocked: Bool = false
    var errorMessage: String = ""
    var showError: Bool = false
    var didSave: Bool = false

    private let service: SessionManagementService

    init(
        session: Session,
        service: SessionManagementService = SessionManagementService()
    ) {
        self.session = session
        self.service = service
    }

    func onAppear() async {
        isLoading = true
        defer { isLoading = false }

        // Determine lock state before loading so the UI shows the correct mode.
        await refreshLockStatus()

        do {
            let questions = try await service.fetchRubricQuestions(sessionId: session.id)
            questionEntries = questions.map {
                RubricQuestionEntry(id: $0.id, prompt: $0.prompt, maxScore: $0.maxScore)
            }
            if questionEntries.isEmpty {
                questionEntries = [RubricQuestionEntry()]
            }
        } catch {
            displayError("Failed to load rubric: \(error.localizedDescription)")
        }
    }

    // Sets isLocked based on whether any submitted score exists for the session.
    private func refreshLockStatus() async {
        do {
            try await service.lockRubricEdits(sessionId: session.id)
            isLocked = false
        } catch {
            isLocked = true
        }
    }

    func addQuestion() {
        questionEntries.append(RubricQuestionEntry())
    }

    func removeQuestion(at offsets: IndexSet) {
        questionEntries.remove(atOffsets: offsets)
        if questionEntries.isEmpty {
            questionEntries.append(RubricQuestionEntry())
        }
    }

    func save() async {
        guard !isLocked else {
            displayError(SessionValidationError.rubricLocked.localizedDescription ?? "Rubric is locked.")
            return
        }

        isSaving = true
        defer { isSaving = false }

        let existing: [RubricQuestion]
        do {
            existing = try await service.fetchRubricQuestions(sessionId: session.id)
        } catch {
            displayError("Failed to fetch existing rubric: \(error.localizedDescription)")
            return
        }

        let newQuestions = questionEntries
            .filter { !$0.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .enumerated()
            .map { index, entry in
                RubricQuestion(
                    id: entry.id,
                    prompt: entry.prompt.trimmingCharacters(in: .whitespacesAndNewlines),
                    maxScore: entry.maxScore,
                    weight: 1.0,
                    order: index,
                    isRequired: true
                )
            }

        do {
            // Delete questions that were removed
            let newIds = Set(newQuestions.map { $0.id })
            for old in existing where !newIds.contains(old.id) {
                try await service.deleteRubricQuestion(questionId: old.id, sessionId: session.id)
            }
            // Save new and updated questions
            for question in newQuestions {
                try await service.saveRubricQuestion(question, sessionId: session.id)
            }
            didSave = true
        } catch SessionValidationError.rubricLocked {
            isLocked = true
            displayError(SessionValidationError.rubricLocked.localizedDescription ?? "Rubric is locked.")
        } catch {
            displayError("Failed to save rubric: \(error.localizedDescription)")
        }
    }

    private func displayError(_ message: String) {
        errorMessage = message
        showError = true
    }
}

// MARK: - View

struct CreateEditRubricView: View {
    @Bindable var viewModel: CreateEditRubricVM
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                form
                    .scrollContentBackground(.hidden)
                    .background(Studio.Palette.canvas.ignoresSafeArea())

                if viewModel.isLoading {
                    ProgressView("Loading rubric…")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .navigationTitle("Edit Rubric")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(viewModel.isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Button("Save") {
                            Task { await viewModel.save() }
                        }
                        .disabled(viewModel.isLocked || viewModel.isLoading)
                    }
                }
            }
            .alert("Cannot Save", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage)
            }
            .onChange(of: viewModel.didSave) { _, saved in
                if saved { dismiss() }
            }
            .task { await viewModel.onAppear() }
            .disabled(viewModel.isSaving)
        }
    }

    private var form: some View {
        Form {
            if viewModel.isLocked {
                lockedBanner
            }

            Section {
                ForEach($viewModel.questionEntries) { $entry in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            TextField("Question prompt", text: $entry.prompt, axis: .vertical)
                                .disabled(viewModel.isLocked)
                            if viewModel.questionEntries.count > 1 && !viewModel.isLocked {
                                Button {
                                    if let index = viewModel.questionEntries.firstIndex(where: { $0.id == entry.id }) {
                                        viewModel.removeQuestion(at: IndexSet(integer: index))
                                    }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Stepper(value: $entry.maxScore, in: 1...100) {
                            Text("Max score: \(entry.maxScore)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .disabled(viewModel.isLocked)
                    }
                    .padding(.vertical, 2)
                }

                if !viewModel.isLocked {
                    Button {
                        viewModel.addQuestion()
                    } label: {
                        Label("Add Question", systemImage: "plus.circle")
                    }
                }
            } header: {
                Text("Questions")
            } footer: {
                if viewModel.isLocked {
                    Text("Rubric editing is disabled once scoring has started.")
                        .foregroundStyle(.orange)
                } else {
                    Text("Interviewers score each question from 1 to its max. At least one question is required.")
                }
            }
        }
    }

    private var lockedBanner: some View {
        Section {
            HStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.orange)
                Text("Scoring has started — this rubric is read-only.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
}
