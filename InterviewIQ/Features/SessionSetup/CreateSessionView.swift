import SwiftUI

// Unified home screen (AGENTS.md Q1-B). Shows sessions the user owns and
// sessions they have been assigned to as a panelist. Both roles are accessible
// from the same screen; ownership is session-scoped, not a global role.
struct SessionDashboardView: View {
    @Bindable var viewModel: SessionDashboardVM
    @State private var showingProfile = false
    @State private var showTutorial = false
    @AppStorage("studio.hasSeenTutorial") private var hasSeenTutorial = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                StudioHeader(title: "Sessions", subtitle: "Manage and run your interviews")
                    .padding(.horizontal, Studio.Spacing.md)
                    .padding(.top, Studio.Spacing.xs)
                    .padding(.bottom, Studio.Spacing.sm)

                sessionList
            }
            .background(Studio.Palette.canvas.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showTutorial = true } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .accessibilityLabel("How it works")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { viewModel.showCreateSheet = true } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingProfile = true } label: {
                        Image(systemName: "person.crop.circle")
                    }
                }
            }
            // Profile sheet
            .sheet(isPresented: $showingProfile) {
                ProfileView(userId: viewModel.userId)
            }
            // Tutorial sheet — auto-shown once, reopenable from the "?" button
            .sheet(isPresented: $showTutorial) {
                TutorialView()
            }
            // Create session sheet
            .sheet(isPresented: $viewModel.showCreateSheet) {
                CreateEditSessionView(
                    viewModel: CreateEditSessionVM(adminId: viewModel.userId)
                )
                .onDisappear { Task { await viewModel.loadSessions() } }
            }
            // Edit session sheet
            .sheet(item: $viewModel.sessionToEdit) { session in
                CreateEditSessionView(
                    viewModel: CreateEditSessionVM(adminId: viewModel.userId, existingSession: session)
                )
                .onDisappear { Task { await viewModel.loadSessions() } }
            }
            // Per-session team management sheet
            .sheet(item: $viewModel.sessionForTeam) { session in
                UserManagementView(
                    viewModel: UserManagementVM(session: session, currentUserId: viewModel.userId)
                )
            }
            // Per-session rubric editing sheet
            .sheet(item: $viewModel.sessionForRubric) { session in
                CreateEditRubricView(
                    viewModel: CreateEditRubricVM(session: session)
                )
                .onDisappear { Task { await viewModel.loadSessions() } }
            }
            // Delete confirmation
            .confirmationDialog("Delete Session?", isPresented: $viewModel.showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    Task { await viewModel.confirmDelete() }
                }
                Button("Cancel", role: .cancel) { viewModel.cancelDelete() }
            } message: {
                if let title = viewModel.sessionToDelete?.title {
                    Text("\"\(title)\" will be permanently removed.")
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
        .task { await viewModel.loadSessions() }
        .onAppear {
            // First-time users get the walkthrough automatically; afterwards it
            // lives behind the "?" button.
            if !hasSeenTutorial {
                hasSeenTutorial = true
                showTutorial = true
            }
        }
    }

    // MARK: - Session list

    private var sessionList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Studio.Spacing.lg) {
                if viewModel.isLoading && viewModel.ownedSessions.isEmpty && viewModel.assignedSessions.isEmpty {
                    ProgressView("Loading sessions…")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                } else if viewModel.ownedSessions.isEmpty && viewModel.assignedSessions.isEmpty {
                    ContentUnavailableView(
                        "No Sessions",
                        systemImage: "calendar.badge.plus",
                        description: Text("Tap + to create your first session, or wait to be assigned as a panelist.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 420)
                } else {
                    if !viewModel.ownedSessions.isEmpty {
                        section(title: "My Sessions") {
                            ForEach(viewModel.ownedSessions) { session in
                                OwnedSessionRow(
                                    session: session,
                                    ownerId:      viewModel.userId,
                                    onEdit:       { viewModel.sessionToEdit    = session },
                                    onManageTeam: { viewModel.sessionForTeam   = session },
                                    onEditRubric: { viewModel.sessionForRubric = session },
                                    onDelete:     { viewModel.requestDelete(session) }
                                )
                            }
                        }
                    }

                    if !viewModel.assignedSessions.isEmpty {
                        section(title: "Assigned to Me") {
                            ForEach(viewModel.assignedSessions) { session in
                                AssignedSessionRow(session: session, interviewerId: viewModel.userId)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Studio.Spacing.md)
            .padding(.bottom, Studio.Spacing.lg)
        }
        .refreshable { await viewModel.loadSessions() }
    }

    @ViewBuilder
    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Studio.Spacing.xs) {
            Text(title)
                .font(.studioDisplay(15, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, Studio.Spacing.xxs)
            content()
        }
    }
}

// MARK: - Session icon

private struct SessionIcon: View {
    let systemName: String
    let colors: [Color]

    var body: some View {
        RoundedRectangle(cornerRadius: Studio.Radius.chip, style: .continuous)
            .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 46, height: 46)
            .overlay {
                Image(systemName: systemName)
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .shadow(color: (colors.first ?? .clear).opacity(0.3), radius: 5, y: 3)
    }
}

// MARK: - Owned session row

// Full action surface for a session the current user created.
// Primary tap → Dashboard. Context menu exposes Rate, Manage Team, Edit Rubric, Edit, Delete.
private struct OwnedSessionRow: View {
    let session: Session
    let ownerId: String
    let onEdit: () -> Void
    let onManageTeam: () -> Void
    let onEditRubric: () -> Void
    let onDelete: () -> Void

    var body: some View {
        NavigationLink {
            DashboardComparisonView(sessionId: session.id, sessionTitle: session.title)
        } label: {
            rowContent
        }
        .buttonStyle(.plain)
        .contextMenu {
            NavigationLink {
                LiveRatingScreen(sessionId: session.id, interviewerId: ownerId)
            } label: {
                Label("Rate Candidates", systemImage: "checklist")
            }
            Button(action: onManageTeam) {
                Label("Manage Team", systemImage: "person.2.badge.gearshape")
            }
            Button(action: onEditRubric) {
                Label("Edit Rubric", systemImage: "list.bullet.clipboard")
            }
            Divider()
            Button(action: onEdit) {
                Label("Edit Session", systemImage: "pencil")
            }
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var rowContent: some View {
        HStack(spacing: Studio.Spacing.md) {
            SessionIcon(systemName: "calendar",
                        colors: [Studio.Palette.accent, Studio.Palette.accentAlt])

            VStack(alignment: .leading, spacing: 3) {
                Text(session.title).font(.headline)
                Text(session.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: Studio.Spacing.sm)

            // Owner badge
            Image(systemName: "crown.fill")
                .font(.caption)
                .foregroundStyle(Studio.Palette.accent)
                .padding(7)
                .background(Studio.Palette.accent.opacity(0.12), in: Circle())

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .studioCard(padding: Studio.Spacing.md)
    }
}

// MARK: - Assigned session row

// Panelist view: tap card body → candidate list → rating.
// Chart button → dashboard.
private struct AssignedSessionRow: View {
    let session: Session
    let interviewerId: String

    @State private var goToRating    = false
    @State private var goToDashboard = false

    var body: some View {
        HStack(spacing: Studio.Spacing.md) {
            Button { goToRating = true } label: {
                HStack(spacing: Studio.Spacing.md) {
                    SessionIcon(systemName: "checklist",
                                colors: [Studio.Palette.scoreHigh, Studio.Palette.scoreHigh.opacity(0.65)])

                    VStack(alignment: .leading, spacing: 3) {
                        Text(session.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(session.date, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)

            Button { goToDashboard = true } label: {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(Studio.Palette.accent)
                    .padding(8)
                    .background(Studio.Palette.accent.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .studioCard(padding: Studio.Spacing.md)
        .navigationDestination(isPresented: $goToRating) {
            LiveRatingScreen(sessionId: session.id, interviewerId: interviewerId)
        }
        .navigationDestination(isPresented: $goToDashboard) {
            DashboardComparisonView(sessionId: session.id, sessionTitle: session.title)
        }
    }
}
