//
//  ScoringCoachOverlay.swift
//  InterviewIQ
//
//  One-time coach mark shown the first time an interviewer enters live scoring
//  (gated by InterviewRatingView via @AppStorage). Just-in-time teaching of the
//  three things that trip up first-timers: how to score, how to navigate, and
//  that submission is final.
//

import SwiftUI

struct ScoringCoachOverlay: View {
    let onDismiss: () -> Void

    private let tips: [(icon: String, text: String)] = [
        ("hand.tap.fill", "Tap a number to score each answer."),
        ("arrow.left.arrow.right", "Use Previous / Next — or the dots — to move between questions."),
        ("checkmark.seal.fill", "Submitting is final. Scores can't be edited afterwards.")
    ]

    var body: some View {
        ZStack {
            // Frosted scrim focuses attention without going dark.
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(alignment: .leading, spacing: Studio.Spacing.lg) {
                VStack(alignment: .leading, spacing: Studio.Spacing.xs) {
                    Text("Scoring, quickly")
                        .font(.title2).fontWeight(.bold)
                    Text("Three things before you start.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: Studio.Spacing.md) {
                    ForEach(tips.indices, id: \.self) { i in
                        HStack(spacing: Studio.Spacing.md) {
                            Image(systemName: tips[i].icon)
                                .font(.title3)
                                .foregroundStyle(Studio.Palette.accent)
                                .frame(width: 30)
                            Text(tips[i].text)
                                .font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                    }
                }

                Button("Got it", action: onDismiss)
                    .buttonStyle(StudioPrimaryButtonStyle())
            }
            .studioCard(radius: Studio.Radius.hero, padding: Studio.Spacing.lg)
            .padding(Studio.Spacing.lg)
        }
    }
}

#Preview("Scoring coach") {
    ZStack {
        Studio.Palette.canvas.ignoresSafeArea()
        ScoringCoachOverlay {}
    }
}
