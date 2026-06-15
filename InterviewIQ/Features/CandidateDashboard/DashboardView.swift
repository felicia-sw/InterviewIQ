//
//  DashboardView.swift
//  InterviewIQ
//
//  Created by Clarice Harijanto on 01/06/26.
//  Restyled to the Studio "Workspace" state: a bento header (top-candidate
//  hero ring + avg/count tiles) over a ledger of contextually-tinted rows.
//

import SwiftUI

// DashboardComparisonView (C-09): UC-05 read-only ranked candidate dashboard.
// Triggered from the SessionDashboard when a user taps "View Dashboard" on a session row.
struct DashboardComparisonView: View {
    let sessionId: String
    let sessionTitle: String

    @State private var viewModel = DashboardComparisonVM()

    // Export state
    @State private var exportedURL: URL?
    @State private var showShareSheet: Bool = false
    @State private var showExportFormatSheet: Bool = false

    // Tapping a ranking row opens its notes + on-device AI summary.
    @State private var summaryCandidate: RankedCandidate?

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading rankings…")
            } else if !viewModel.hasData {
                emptyState
            } else {
                dashboardContent
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showExportFormatSheet = true
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .disabled(!viewModel.hasData || viewModel.isExporting)
            }
        }
        // Format picker
        .confirmationDialog("Export Report", isPresented: $showExportFormatSheet, titleVisibility: .visible) {
            Button("Export as PDF") {
                Task { await handleExport(format: .pdf) }
            }
            Button("Export as CSV") {
                Task { await handleExport(format: .csv) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose a format for the \"\(sessionTitle)\" report.")
        }
        // Share sheet
        .sheet(isPresented: $showShareSheet) {
            if let url = exportedURL {
                ShareSheet(url: url)
            }
        }
        // Candidate notes + AI summary
        .sheet(item: $summaryCandidate) { candidate in
            CandidateSummarySheet(candidate: candidate)
        }
        // Error
        .alert("Export Failed", isPresented: $viewModel.showExportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.exportErrorMessage)
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
        .task {
            viewModel.sessionId = sessionId
            viewModel.sessionTitle = sessionTitle
            await viewModel.loadDashboard()
        }
        .refreshable {
            await viewModel.loadDashboard()
        }
    }

    // MARK: - Dashboard Content

    private var dashboardContent: some View {
        ScrollView {
            VStack(spacing: Studio.Spacing.lg) {
                StudioHeader(title: "Dashboard", subtitle: sessionTitle)
                bentoHeader
                ledger
            }
            .padding(Studio.Spacing.md)
        }
        .background(Studio.Palette.canvas.ignoresSafeArea())
    }

    // MARK: - Bento Header

    private var bentoHeader: some View {
        VStack(spacing: Studio.Spacing.sm) {
            heroTile
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: Studio.Spacing.sm),
                    GridItem(.flexible(), spacing: Studio.Spacing.sm)
                ],
                spacing: Studio.Spacing.sm
            ) {
                avgTile
                countTile
            }
        }
    }

    // Full-width hero: top candidate with a big score ring.
    private var heroTile: some View {
        HStack(spacing: Studio.Spacing.md) {
            VStack(alignment: .leading, spacing: Studio.Spacing.xxs) {
                Text("Top Candidate")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Text(viewModel.topCandidate?.name ?? "—")
                    .font(.title2).fontWeight(.bold)
                    .lineLimit(1)
                if let submitted = viewModel.topCandidate?.submittedAt {
                    Text("Submitted \(submitted, style: .relative) ago")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: Studio.Spacing.sm)
            ScoreRing(score: viewModel.topCandidate?.totalScore ?? 0, size: 88, lineWidth: 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .studioCard(radius: Studio.Radius.hero, padding: Studio.Spacing.lg)
    }

    private var avgTile: some View {
        VStack(spacing: Studio.Spacing.sm) {
            ScoreRing(score: viewModel.averageScore, size: 72, lineWidth: 8)
            Text("Avg Score")
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 116)
        .studioCard()
    }

    private var countTile: some View {
        VStack(alignment: .leading, spacing: Studio.Spacing.xxs) {
            Text("\(viewModel.rankedCandidates.count)")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Studio.Palette.accent)
            Text("Candidates")
                .font(.caption).foregroundStyle(.secondary)
            Spacer(minLength: 0)
            if let top = viewModel.topCandidate {
                Text("Top \(top.totalScore)%")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(Studio.scoreColor(for: top.totalScore))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
        .studioCard()
    }

    // MARK: - Ledger

    private var ledger: some View {
        VStack(alignment: .leading, spacing: Studio.Spacing.sm) {
            Text("Rankings")
                .font(.title3).fontWeight(.semibold)
                .padding(.horizontal, Studio.Spacing.xxs)

            VStack(spacing: Studio.Spacing.xs) {
                ForEach(viewModel.rankedCandidates) { candidate in
                    Button {
                        summaryCandidate = candidate
                    } label: {
                        LedgerRow(candidate: candidate)
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("Tap a candidate to read notes and generate an AI summary.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, Studio.Spacing.xxs)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView(
            "No Results Yet",
            systemImage: "chart.bar.xaxis",
            description: Text("Rankings will appear here once interviewers have submitted scores.")
        )
    }

    // MARK: - Export Handler

    private enum ExportFormat { case pdf, csv }

    private func handleExport(format: ExportFormat) async {
        let url: URL?
        switch format {
        case .pdf: url = await viewModel.exportPDF()
        case .csv: url = await viewModel.exportCSV()
        }
        if let url {
            exportedURL = url
            showShareSheet = true
        }
    }
}

// MARK: - Ledger Row

// Editorial "Ledger" row: a large rank numeral, the name, a per-question
// sparkline, a tinted score spine, and the percentage — the whole row washed
// with a faint monochromatic tint of its score (Studio contextual tinting).
private struct LedgerRow: View {
    let candidate: RankedCandidate

    private var scoreColor: Color { Studio.scoreColor(for: candidate.totalScore) }
    private var sparkValues: [Int] { candidate.questionScores.map(\.score) }

    @ViewBuilder private var panelMeta: some View {
        if candidate.panelistCount > 1 {
            HStack(spacing: Studio.Spacing.xs) {
                HStack(spacing: 3) {
                    Image(systemName: "person.2.fill").font(.system(size: 9))
                    Text("\(candidate.panelistCount) panelists").font(.caption2)
                }
                .foregroundStyle(.secondary)

                if candidate.hasDisagreement {
                    Text("Split ±\(candidate.scoreSpread)")
                        .font(.caption2).fontWeight(.semibold)
                        .foregroundStyle(Studio.Palette.scoreMid)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Studio.Palette.scoreMid.opacity(0.15), in: Capsule())
                }
            }
        }
    }

    var body: some View {
        HStack(spacing: Studio.Spacing.md) {
            // Rank numeral — bold + tinted for the podium, light + muted otherwise.
            Text("\(candidate.rank)")
                .font(.system(size: 34, weight: candidate.rank <= 3 ? .bold : .light, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(candidate.rank <= 3 ? scoreColor : .secondary)
                .frame(width: 40, alignment: .leading)

            VStack(alignment: .leading, spacing: Studio.Spacing.xxs) {
                Text(candidate.name)
                    .font(.headline)

                panelMeta

                if sparkValues.count >= 2 {
                    Sparkline(values: sparkValues, color: scoreColor.opacity(0.7))
                        .frame(height: 16)
                } else if let submitted = candidate.submittedAt {
                    Text("Submitted \(submitted, style: .relative) ago")
                        .font(.caption2).foregroundStyle(.secondary)
                }

                // Score spine
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.secondary.opacity(0.15))
                        Capsule().fill(scoreColor)
                            .frame(width: geo.size.width * CGFloat(candidate.totalScore) / 100)
                    }
                }
                .frame(height: 5)
            }

            Text("\(candidate.totalScore)%")
                .font(.title3).fontWeight(.bold)
                .monospacedDigit()
                .foregroundStyle(scoreColor)
        }
        .studioCard(fill: Studio.scoreTint(for: candidate.totalScore), padding: Studio.Spacing.md)
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}

// MARK: - Preview (sample data, no Firebase required)

private struct LedgerPreviewHost: View {
    private let sample: [RankedCandidate] = [
        RankedCandidate(id: "1", name: "Maya Chen", totalScore: 91, rank: 1,
                        submittedAt: Date(), interviewerId: "x",
                        questionScores: [.init(questionId: "a", score: 5), .init(questionId: "b", score: 4),
                                         .init(questionId: "c", score: 5), .init(questionId: "d", score: 4)],
                        notes: "", panelistCount: 3, scoreSpread: 6),
        RankedCandidate(id: "2", name: "Jordan Reyes", totalScore: 72, rank: 2,
                        submittedAt: Date(), interviewerId: "x",
                        questionScores: [.init(questionId: "a", score: 3), .init(questionId: "b", score: 4),
                                         .init(questionId: "c", score: 2), .init(questionId: "d", score: 5)],
                        notes: "", panelistCount: 3, scoreSpread: 22),
        RankedCandidate(id: "3", name: "Sam Okafor", totalScore: 54, rank: 3,
                        submittedAt: Date(), interviewerId: "x",
                        questionScores: [.init(questionId: "a", score: 2), .init(questionId: "b", score: 3),
                                         .init(questionId: "c", score: 2)],
                        notes: "", panelistCount: 2, scoreSpread: 10)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: Studio.Spacing.xs) {
                ForEach(sample) { LedgerRow(candidate: $0) }
            }
            .padding()
        }
        .background(Studio.Palette.canvas)
    }
}

#Preview("Ledger · Workspace") { LedgerPreviewHost() }
