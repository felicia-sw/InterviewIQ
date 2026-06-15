//
//  StudioComponents.swift
//  InterviewIQ
//
//  Reusable building blocks for the Studio design system so the same language
//  flows across every screen and modal: the card style, score visualisations,
//  and the primary/secondary button styles. All light, all iOS 26-native.
//

import SwiftUI

// MARK: - Card

struct StudioCard: ViewModifier {
    var radius: CGFloat = Studio.Radius.card
    var fill: Color = Studio.Palette.tile
    var padding: CGFloat = Studio.Spacing.md

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            // Layered soft float with a faint accent-tinted ambient shadow — the Studio signature.
            .shadow(color: .black.opacity(0.05), radius: 1, y: 1)
            .shadow(color: Studio.Palette.accent.opacity(0.10), radius: 18, y: 10)
    }
}

extension View {
    func studioCard(radius: CGFloat = Studio.Radius.card,
                    fill: Color = Studio.Palette.tile,
                    padding: CGFloat = Studio.Spacing.md) -> some View {
        modifier(StudioCard(radius: radius, fill: fill, padding: padding))
    }
}

// MARK: - Score ring (gauges)

struct ScoreRing: View {
    let score: Int               // 0...100
    var size: CGFloat = 88
    var lineWidth: CGFloat = 10
    var showsLabel: Bool = true

    private var color: Color { Studio.scoreColor(for: score) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(max(0, min(score, 100))) / 100)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if showsLabel {
                Text("\(score)")
                    .font(.system(size: size * 0.30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(color)
            }
        }
        .frame(width: size, height: size)
        .animation(.smooth, value: score)
    }
}

// MARK: - Sparkline (per-question consistency)

struct Sparkline: View {
    let values: [Int]
    var color: Color = .secondary

    var body: some View {
        Canvas { context, size in
            guard values.count > 1 else { return }
            let maxV = CGFloat(max(values.max() ?? 1, 1))
            let stepX = size.width / CGFloat(values.count - 1)
            var path = Path()
            for (i, v) in values.enumerated() {
                let x = CGFloat(i) * stepX
                let y = size.height - (CGFloat(v) / maxV) * size.height
                if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
            context.stroke(path, with: .color(color),
                           style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
    }
}

// MARK: - Button styles

// Primary call-to-action: accent gradient fill, white label. Use for the main
// action on any screen or modal (Submit, Get Started, Save, Continue…).
struct StudioPrimaryButtonStyle: ButtonStyle {
    /// Override the gradient with a solid tint (e.g. green for a completed Submit).
    var tint: Color? = nil

    func makeBody(configuration: Configuration) -> some View {
        StyledLabel(configuration: configuration, tint: tint)
    }

    private struct StyledLabel: View {
        let configuration: ButtonStyleConfiguration
        let tint: Color?
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background {
                    let shape = RoundedRectangle(cornerRadius: Studio.Radius.chip, style: .continuous)
                    if let tint {
                        shape.fill(tint)
                    } else {
                        shape.fill(Studio.accentGradient)
                    }
                }
                .shadow(color: (tint ?? Studio.Palette.accent).opacity(isEnabled ? 0.30 : 0),
                        radius: configuration.isPressed ? 3 : 10, y: 4)
                .opacity(isEnabled ? (configuration.isPressed ? 0.9 : 1) : 0.4)
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .animation(.snappy(duration: 0.18), value: configuration.isPressed)
        }
    }
}

// Secondary action: soft tinted accent surface (Previous, Cancel, Skip…).
struct StudioSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        StyledLabel(configuration: configuration)
    }

    private struct StyledLabel: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.headline)
                .foregroundStyle(Studio.Palette.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Studio.Palette.accent.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: Studio.Radius.chip, style: .continuous))
                .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.35)
        }
    }
}

// MARK: - Branded header

// Replaces the stock large-title-on-grouped-list look with a signature header:
// a rounded display title plus a short accent-gradient underline motif that
// recurs across every screen.
struct StudioHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Studio.Spacing.xs) {
            Text(title)
                .font(.studioDisplay(34))
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Studio.accentGradient)
                .frame(width: 44, height: 4)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
