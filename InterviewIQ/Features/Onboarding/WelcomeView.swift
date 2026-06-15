//
//  WelcomeView.swift
//  InterviewIQ
//
//  First-run welcome, shown once after the first successful login (gated by
//  ContentView via @AppStorage). Role-aware: interviewers and admins each see
//  the mechanics that matter to their job, in the light Studio language.
//

import SwiftUI

struct WelcomeView: View {
    let profile: UserProfile
    let onGetStarted: () -> Void

    private var firstName: String {
        profile.fullName.split(separator: " ").first.map(String.init) ?? profile.fullName
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Studio.Spacing.xl) {
                header
                VStack(spacing: Studio.Spacing.md) {
                    ForEach(highlights) { HighlightRow(highlight: $0) }
                }
            }
            .padding(Studio.Spacing.lg)
            .padding(.top, Studio.Spacing.xl)
        }
        .background(Studio.Palette.canvas)
        .safeAreaInset(edge: .bottom) {
            Button("Get Started", action: onGetStarted)
                .buttonStyle(StudioPrimaryButtonStyle())
                .padding(Studio.Spacing.lg)
                .background(.regularMaterial)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Studio.Spacing.sm) {
            Image(systemName: "checklist")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Studio.accentGradient)
            Text("Welcome, \(firstName)")
                .font(.largeTitle).fontWeight(.bold)
            Text(profile.role == .admin
                 ? "Here's how you'll run interviews in InterviewIQ."
                 : "Here's how you'll score interviews in InterviewIQ.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Role-aware highlights

    private var highlights: [Highlight] {
        switch profile.role {
        case .interviewer:
            return [
                Highlight(icon: "slider.horizontal.3", title: "Score in the moment",
                          detail: "Tap a number to rate each answer, then swipe through the rubric — eyes on the candidate, not the screen."),
                Highlight(icon: "checkmark.seal.fill", title: "Submitting is final",
                          detail: "Once you submit a candidate's scores they're locked and can't be edited, so review before you send."),
                Highlight(icon: "wifi.slash", title: "Works offline",
                          detail: "Lost signal? Your scores save on-device and sync automatically when you're back online.")
            ]
        case .admin:
            return [
                Highlight(icon: "square.grid.2x2.fill", title: "Build sessions & rubrics",
                          detail: "Create an interview session, add candidates, and define the scoring rubric your panel will use."),
                Highlight(icon: "person.2.fill", title: "Assign your panel",
                          detail: "Add interviewers to a session — each candidate is locked to one panelist at a time to avoid clashes."),
                Highlight(icon: "chart.bar.xaxis", title: "Compare & export",
                          detail: "Watch the ranked dashboard fill in as scores land, then export the results as PDF or CSV.")
            ]
        }
    }

    struct Highlight: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let detail: String
    }

    private struct HighlightRow: View {
        let highlight: Highlight

        var body: some View {
            HStack(alignment: .top, spacing: Studio.Spacing.md) {
                Image(systemName: highlight.icon)
                    .font(.title2)
                    .foregroundStyle(Studio.Palette.accent)
                    .frame(width: 40, height: 40)
                    .background(Studio.Palette.accent.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: Studio.Radius.chip, style: .continuous))

                VStack(alignment: .leading, spacing: Studio.Spacing.xxs) {
                    Text(highlight.title)
                        .font(.headline)
                    Text(highlight.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .studioCard()
        }
    }
}

// MARK: - Previews (no Firebase required)

#Preview("Welcome · Interviewer") {
    WelcomeView(profile: UserProfile(userId: "1", fullName: "Maya Chen",
                                     emailAddress: "m@example.com", role: .interviewer)) {}
}

#Preview("Welcome · Admin") {
    WelcomeView(profile: UserProfile(userId: "2", fullName: "Jordan Reyes",
                                     emailAddress: "j@example.com", role: .admin)) {}
}
