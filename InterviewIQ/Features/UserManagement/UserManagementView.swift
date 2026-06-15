import Foundation
import SwiftUI

// MARK: - ViewModel

// UserManagementVM (AGENTS.md Section 2): manages per-session panelist assignment.
// Uses UserAccessService to enforce ownership before any mutation.
@Observable
final class UserManagementVM {
    private(set) var session: Session
    let currentUserId: String

    var panelists: [UserProfile] = []
    var emailInput: String = ""
    var isAdding: Bool = false
    var isLoading: Bool = false
    var errorMessage: String = ""
    var showError: Bool = false

    private let accessService: UserAccessService

    init(
        session: Session,
        currentUserId: String,
        accessService: UserAccessService = UserAccessService()
    ) {
        self.session = session
        self.currentUserId = currentUserId
        self.accessService = accessService
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            panelists = try await accessService.fetchPanelists(for: session)
        } catch {
            displayError("Failed to load panelists: \(error.localizedDescription)")
        }
    }

    func attachPanelistByEmail() async {
        let email = emailInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty else { return }

        isAdding = true
        defer { isAdding = false }

        do {
            try accessService.verifyAdminRights(userId: currentUserId, session: session)

            guard let user = try await accessService.findUserByEmail(email) else {
                displayError(UserAccessError.userNotFound.localizedDescription ?? "User not found.")
                return
            }
            try await accessService.attachPanelist(userId: user.userId, to: session)
            emailInput = ""
            // Optimistic update: show the new panelist immediately without waiting
            // for another Firebase round-trip. Also keep session.interviewerIds in
            // sync so a subsequent add doesn't overwrite this one.
            panelists.append(user)
            session.interviewerIds.append(user.userId)
            await load()
        } catch let error as UserAccessError {
            displayError(error.localizedDescription ?? error.localizedDescription)
        } catch {
            displayError("Failed to assign panelist: \(error.localizedDescription)")
        }
    }

    func removePanelist(_ profile: UserProfile) async {
        do {
            try accessService.verifyAdminRights(userId: currentUserId, session: session)
            // Remove from UI immediately — session.interviewerIds still contains the id
            // so the service guard passes correctly.
            panelists.removeAll { $0.userId == profile.userId }
            try await accessService.removePanelist(userId: profile.userId, from: session)
            session.interviewerIds.removeAll { $0 == profile.userId }
            await load()
        } catch let error as UserAccessError {
            await load()  // restore list to actual server state on failure
            displayError(error.localizedDescription ?? error.localizedDescription)
        } catch {
            await load()  // restore list to actual server state on failure
            displayError("Failed to remove panelist: \(error.localizedDescription)")
        }
    }

    private func displayError(_ message: String) {
        errorMessage = message
        showError = true
    }
}

// MARK: - View

// Per-session panelist management screen. Accessible from the session row in
// SessionDashboardView for the session owner only.
struct UserManagementView: View {
    @State var viewModel: UserManagementVM
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoading && viewModel.panelists.isEmpty {
                    ProgressView("Loading panelists…")
                } else {
                    panelistList
                }
            }
            .navigationTitle("Manage Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage)
            }
            .task { await viewModel.load() }
        }
    }

    // MARK: - Panelist list

    private var panelistList: some View {
        List {
            addSection
            if !viewModel.panelists.isEmpty {
                assignedSection
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Studio.Palette.canvas)
        .refreshable { await viewModel.load() }
    }

    private var addSection: some View {
        Section {
            HStack {
                TextField("Email address", text: $viewModel.emailInput)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .onSubmit { Task { await viewModel.attachPanelistByEmail() } }

                if viewModel.isAdding {
                    ProgressView()
                } else {
                    Button {
                        Task { await viewModel.attachPanelistByEmail() }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color.brandPurple)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.emailInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        } header: {
            Text("Add Panelist")
        } footer: {
            Text("Enter the email address of any registered user to assign them as a panelist for \"\(viewModel.session.title)\".")
        }
    }

    private var assignedSection: some View {
        Section("Assigned Panelists (\(viewModel.panelists.count))") {
            ForEach(viewModel.panelists, id: \.userId) { panelist in
                PanelistRow(panelist: panelist) {
                    Task { await viewModel.removePanelist(panelist) }
                }
            }
        }
    }
}

// MARK: - Row

private struct PanelistRow: View {
    let panelist: UserProfile
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(panelist.fullName.prefix(1).uppercased())
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Studio.accentGradient, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(panelist.fullName)
                    .font(.headline)
                Text(panelist.emailAddress)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(role: .destructive, action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }
}
