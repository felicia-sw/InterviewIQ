import SwiftUI

// Shows the interviewer's list of candidates for a session.
// Tapping "Start Interview" acquires a candidate lock and enters the rating phase.
struct CandidateListView: View {
    @Bindable var viewModel: LiveRatingVM

    var body: some View {
        ZStack {
            if viewModel.isLoading && viewModel.candidates.isEmpty {
                ProgressView("Loading candidates…")
            } else if viewModel.candidates.isEmpty {
                emptyState
            } else {
                content
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                syncStatusBadge
            }
        }
        .refreshable {
            await viewModel.loadCandidates()
        }
    }

    // MARK: - Content

    private var content: some View {
        ScrollView {
            VStack(spacing: Studio.Spacing.md) {
                StudioHeader(title: "Candidates",
                             subtitle: "\(viewModel.candidates.count) in this session")

                progressSummary

                LazyVStack(spacing: Studio.Spacing.xs) {
                    ForEach(viewModel.candidates) { candidate in
                        CandidateCardView(
                            candidate: candidate,
                            status: viewModel.candidateStatus(for: candidate),
                            isLoading: viewModel.isLoading,
                            onStart: { Task { await viewModel.startInterview(with: candidate) } }
                        )
                    }
                }
            }
            .padding(Studio.Spacing.md)
        }
        .background(Studio.Palette.canvas)
    }

    // MARK: - Progress summary

    private var statuses: [String] { viewModel.candidates.map { viewModel.candidateStatus(for: $0) } }
    private var completedCount: Int { statuses.filter { $0 == "Completed" }.count }
    private var inProgressCount: Int { statuses.filter { $0 == "In Progress" }.count }
    private var notStartedCount: Int { statuses.filter { $0 == "Not Started" }.count }

    private var progressSummary: some View {
        VStack(alignment: .leading, spacing: Studio.Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Session progress")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Text("\(completedCount) of \(viewModel.candidates.count) scored")
                    .font(.title2).fontWeight(.bold)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }

            pipelineBar

            HStack(spacing: Studio.Spacing.lg) {
                legend(count: completedCount, label: "Completed", color: Studio.Palette.scoreHigh)
                legend(count: inProgressCount, label: "In progress", color: Studio.Palette.scoreMid)
                legend(count: notStartedCount, label: "Not started", color: .secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .studioCard(padding: Studio.Spacing.lg)
    }

    private var pipelineBar: some View {
        GeometryReader { geo in
            let total = CGFloat(max(viewModel.candidates.count, 1))
            HStack(spacing: 0) {
                Rectangle().fill(Studio.Palette.scoreHigh)
                    .frame(width: geo.size.width * CGFloat(completedCount) / total)
                Rectangle().fill(Studio.Palette.scoreMid)
                    .frame(width: geo.size.width * CGFloat(inProgressCount) / total)
                Rectangle().fill(Color.secondary.opacity(0.18))
            }
        }
        .frame(height: 10)
        .clipShape(Capsule())
        .animation(.smooth, value: completedCount)
    }

    private func legend(count: Int, label: String, color: Color) -> some View {
        HStack(spacing: Studio.Spacing.xs) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text("\(count)").font(.subheadline).fontWeight(.bold).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        ContentUnavailableView(
            "No Candidates",
            systemImage: "person.3",
            description: Text("The session admin hasn't added any candidates yet.")
        )
    }

    // MARK: - Sync status badge
    //
    // Surfaces OfflineSyncManager's state: online/offline, how many scores are
    // queued, an in-flight spinner, and a failure tint. Tapping retries the sync
    // (enabled only when there's something to send and we're online).

    private var sync: OfflineSyncManager { viewModel.syncManager }

    private var syncStatusBadge: some View {
        let pending = sync.pendingCount
        let canRetry = pending > 0 && sync.isOnline && !sync.isSyncing

        let tint: Color = sync.lastSyncFailed ? Studio.Palette.scoreLow
            : pending > 0 ? Studio.Palette.scoreMid
            : sync.isOnline ? Studio.Palette.scoreHigh : .secondary

        return Button {
            sync.retryNow()
        } label: {
            HStack(spacing: 5) {
                if sync.isSyncing {
                    ProgressView().controlSize(.mini)
                } else {
                    Circle().fill(tint).frame(width: 7, height: 7)
                }
                Text(statusLabel(pending: pending))
                    .font(.caption).fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!canRetry)
        .animation(.smooth, value: pending)
        .accessibilityLabel(pending > 0 ? "\(pending) scores pending sync. Tap to retry." : (sync.isOnline ? "All scores synced" : "Offline"))
    }

    private func statusLabel(pending: Int) -> String {
        if sync.isSyncing { return "Syncing…" }
        if sync.lastSyncFailed && pending > 0 { return "\(pending) failed — retry" }
        if pending > 0 { return "\(pending) pending" }
        return sync.isOnline ? "Synced" : "Offline"
    }
}

// MARK: - Candidate card

private struct CandidateCardView: View {
    let candidate: Candidate
    let status: String
    let isLoading: Bool
    let onStart: () -> Void

    private var statusColor: Color {
        switch status {
        case "Completed":   return Studio.Palette.scoreHigh
        case "In Progress": return Studio.Palette.scoreMid
        default:            return Studio.Palette.accent
        }
    }

    var body: some View {
        HStack(spacing: Studio.Spacing.md) {
            // Gradient avatar adds colour + depth.
            Text(candidate.name.prefix(1).uppercased())
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(Studio.accentGradient, in: Circle())
                .shadow(color: Studio.Palette.accent.opacity(0.25), radius: 6, y: 3)

            VStack(alignment: .leading, spacing: 5) {
                Text(candidate.name)
                    .font(.headline)
                Text(status)
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(statusColor.opacity(0.14), in: Capsule())
            }

            Spacer(minLength: Studio.Spacing.sm)

            if status == "Completed" {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title2)
                    .foregroundStyle(Studio.Palette.scoreHigh)
            } else {
                Button(status == "In Progress" ? "Resume" : "Start", action: onStart)
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.regular)
                    .disabled(isLoading)
            }
        }
        .studioCard(padding: Studio.Spacing.md)
    }
}
