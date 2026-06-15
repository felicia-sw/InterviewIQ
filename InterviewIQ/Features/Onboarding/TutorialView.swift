//
//  TutorialView.swift
//  InterviewIQ
//
//  "How it works" walkthrough. Presented as a sheet — auto-shown once for new
//  users (gated by SessionDashboardView via @AppStorage) and always reachable
//  from the "?" button on the home screen. Names each control and its purpose so
//  people aren't left guessing what to tap.
//

import SwiftUI

struct TutorialView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Studio.Spacing.xl) {
                    header
                    ForEach(sections) { section in
                        sectionView(section)
                    }
                }
                .padding(Studio.Spacing.lg)
            }
            .background(Studio.Palette.canvas)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Studio.Spacing.sm) {
            Image(systemName: "sparkles")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(Studio.accentGradient)
            Text("How it works")
                .font(.studioDisplay(32))
            Text("A quick tour of what everything does.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Section

    private func sectionView(_ section: TutorialSection) -> some View {
        VStack(alignment: .leading, spacing: Studio.Spacing.sm) {
            Text(section.title)
                .font(.studioDisplay(15, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, Studio.Spacing.xxs)
            VStack(spacing: Studio.Spacing.xs) {
                ForEach(section.items) { item in
                    TutorialRow(item: item)
                }
            }
        }
    }

    // MARK: - Content

    private var sections: [TutorialSection] {
        [
            TutorialSection(title: "On the home screen", items: [
                TutorialItem(icon: "plus", title: "Create a session",
                             detail: "Tap ＋ in the top corner to set up a new interview — add candidates and build the scoring rubric."),
                TutorialItem(icon: "crown.fill", title: "Sessions you own",
                             detail: "Cards with a crown are yours. Tap one to open its results Dashboard; press and hold for more — Rate, Manage Team, Edit Rubric, Edit, Delete."),
                TutorialItem(icon: "checklist", title: "Sessions assigned to you",
                             detail: "Green cards are sessions you're a panelist on. Tap to open the candidate list and start scoring."),
                TutorialItem(icon: "chart.bar.fill", title: "See results",
                             detail: "The chart button jumps straight to that session's ranked Dashboard."),
                TutorialItem(icon: "person.crop.circle", title: "Your account",
                             detail: "The profile icon shows your details and lets you log out.")
            ]),
            TutorialSection(title: "Scoring an interview", items: [
                TutorialItem(icon: "hand.tap.fill", title: "Score an answer",
                             detail: "Tap a number — 1 up to the question's max — to rate each answer."),
                TutorialItem(icon: "arrow.left.arrow.right", title: "Move between questions",
                             detail: "Use Previous / Next or the dots to jump around the rubric."),
                TutorialItem(icon: "checkmark.seal.fill", title: "Submit when done",
                             detail: "Once every question is scored, Submit sends them. Scores are final and can't be edited afterwards."),
                TutorialItem(icon: "wifi.slash", title: "Offline is fine",
                             detail: "No connection? Scores save on your device and sync automatically when you're back online.")
            ]),
            TutorialSection(title: "Reading the results", items: [
                TutorialItem(icon: "trophy.fill", title: "Rankings",
                             detail: "Candidates are ranked by their weighted score, strongest first."),
                TutorialItem(icon: "square.and.arrow.up", title: "Export",
                             detail: "Share the results as a PDF or CSV from the Dashboard's export button.")
            ])
        ]
    }
}

// MARK: - Models

private struct TutorialSection: Identifiable {
    let id = UUID()
    let title: String
    let items: [TutorialItem]
}

private struct TutorialItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let detail: String
}

// MARK: - Row

private struct TutorialRow: View {
    let item: TutorialItem

    var body: some View {
        HStack(alignment: .top, spacing: Studio.Spacing.md) {
            Image(systemName: item.icon)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(Studio.accentGradient,
                            in: RoundedRectangle(cornerRadius: Studio.Radius.chip, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title).font(.headline)
                Text(item.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .studioCard(padding: Studio.Spacing.md)
    }
}

#Preview { TutorialView() }
