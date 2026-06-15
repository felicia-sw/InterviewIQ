//
//  AuditLogView.swift
//  InterviewIQ
//
//  Activity Log viewer (FR-11). Surfaces the audit trail the app already records
//  — sign-ins, session changes, role changes — which previously had no UI.
//

import SwiftUI

// MARK: - ViewModel

@Observable
final class AuditLogVM {
    private(set) var logs: [AuditLog] = []
    var isLoading = false
    var errorMessage = ""
    var showError = false
    var filter: AuditAction? = nil   // nil == show everything

    private let repo = AuditLogRepository()

    // See [[interviewiq-mainactor-deinit-crash]]: @Observable VMs need a
    // synchronous deinit under the project's MainActor-isolation default.
    nonisolated deinit {}

    var visibleLogs: [AuditLog] {
        guard let filter else { return logs }
        return logs.filter { $0.action == filter }
    }

    /// Action types actually present in the data, for the filter menu.
    var presentActions: [AuditAction] {
        AuditAction.allCases.filter { action in logs.contains { $0.action == action } }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            logs = try await repo.fetchRecent()
        } catch {
            errorMessage = "Couldn't load the activity log: \(error.localizedDescription)"
            showError = true
        }
    }
}

// MARK: - View

struct AuditLogView: View {
    @State private var viewModel = AuditLogVM()

    private static let stamp: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM yyyy · HH:mm"
        return f
    }()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.logs.isEmpty {
                ProgressView("Loading activity…")
            } else if viewModel.logs.isEmpty {
                ContentUnavailableView(
                    "No Activity Yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Sign-ins, session edits and role changes will appear here.")
                )
            } else {
                content
            }
        }
        .navigationTitle("Activity Log")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { filterMenu }
        }
        .background(Studio.Palette.canvas)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .alert("Activity Log", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
    }

    private var content: some View {
        ScrollView {
            LazyVStack(spacing: Studio.Spacing.xs) {
                ForEach(viewModel.visibleLogs) { log in
                    row(for: log)
                }
            }
            .padding(Studio.Spacing.md)
        }
        .background(Studio.Palette.canvas)
    }

    private func row(for log: AuditLog) -> some View {
        let tint = log.action.isSecuritySensitive ? Studio.Palette.scoreLow : Studio.Palette.accent
        return HStack(spacing: Studio.Spacing.md) {
            Image(systemName: log.action.iconName)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(log.action.label)
                    .font(.subheadline).fontWeight(.semibold)
                if !log.details.isEmpty {
                    Text(log.details)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text(Self.stamp.string(from: log.timestamp))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }

            Spacer(minLength: 0)

            if !log.actorRole.isEmpty {
                Text(log.actorRole.capitalized)
                    .font(.caption2).fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
            }
        }
        .studioCard(padding: Studio.Spacing.sm)
    }

    private var filterMenu: some View {
        Menu {
            Button {
                viewModel.filter = nil
            } label: {
                Label("All activity", systemImage: viewModel.filter == nil ? "checkmark" : "")
            }
            ForEach(viewModel.presentActions, id: \.self) { action in
                Button {
                    viewModel.filter = action
                } label: {
                    Label(action.label, systemImage: viewModel.filter == action ? "checkmark" : action.iconName)
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
        }
    }
}
