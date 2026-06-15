//
//  CandidateSummarySheet.swift
//  InterviewIQ
//
//  Opened from a dashboard ranking row. Shows a candidate's combined panel notes
//  (the dictated/typed transcript) and an on-device AI summary of them.
//

import SwiftUI

struct CandidateSummarySheet: View {
    let candidate: RankedCandidate

    @Environment(\.dismiss) private var dismiss
    @State private var summarizer = InterviewSummarizer()
    @State private var summary: InterviewSummary?

    private var notes: String {
        candidate.notes.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Studio.Spacing.lg) {
                    header
                    aiSummaryCard
                    notesCard
                }
                .padding(Studio.Spacing.md)
            }
            .background(Studio.Palette.canvas)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: Studio.Spacing.md) {
            VStack(alignment: .leading, spacing: Studio.Spacing.xxs) {
                Text("Rank #\(candidate.rank)")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Text(candidate.name)
                    .font(.title2).fontWeight(.bold)
                    .lineLimit(2)
                if candidate.panelistCount > 1 {
                    Text("^[\(candidate.panelistCount) panelist](inflect: true)")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: Studio.Spacing.sm)
            ScoreRing(score: candidate.totalScore, size: 76, lineWidth: 9)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .studioCard(radius: Studio.Radius.hero, padding: Studio.Spacing.lg)
    }

    // MARK: - AI summary

    private var aiSummaryCard: some View {
        VStack(alignment: .leading, spacing: Studio.Spacing.sm) {
            Label("AI Summary", systemImage: "sparkles")
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(Studio.Palette.accent)

            switch summarizer.state {
            case .working:
                HStack(spacing: Studio.Spacing.sm) {
                    ProgressView()
                    Text("Summarizing on-device…").font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            case .unavailable(let reason):
                Text(reason).font(.subheadline).foregroundStyle(.secondary)
            case .idle:
                if let summary {
                    Text(summary.text)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(notes.isEmpty
                         ? "No notes to summarize yet."
                         : "Generate a concise, on-device summary of the panel's notes. Nothing leaves this device.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if summary == nil && !notes.isEmpty && summarizer.state != .working {
                Button {
                    Task { summary = await summarizer.summarize(notes: candidate.notes) }
                } label: {
                    Label("Summarize with on-device AI", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(StudioPrimaryButtonStyle())
                .padding(.top, Studio.Spacing.xxs)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .studioCard(padding: Studio.Spacing.lg)
    }

    // MARK: - Raw notes (transcript)

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: Studio.Spacing.sm) {
            Text("Panel Notes")
                .font(.subheadline).fontWeight(.semibold)
            if notes.isEmpty {
                Text("No notes were recorded for this candidate.")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                Text(notes)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .studioCard(padding: Studio.Spacing.lg)
    }
}
