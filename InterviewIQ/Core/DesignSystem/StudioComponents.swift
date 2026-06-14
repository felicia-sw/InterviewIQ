//
//  StudioComponents.swift
//  InterviewIQ
//
//  Reusable building blocks for the Studio design system: the Workspace card
//  style, the dark Stage backdrop + modifier, score visualisations, and the
//  Stage button styles. Screens compose these so the system spreads for free.
//

import SwiftUI

// MARK: - Workspace card

struct StudioCard: ViewModifier {
    var radius: CGFloat = Studio.Radius.card
    var fill: Color = Studio.Palette.tile
    var padding: CGFloat = Studio.Spacing.md

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            // Layered soft float — the Stratus signature.
            .shadow(color: .black.opacity(0.04), radius: 1, y: 1)
            .shadow(color: .black.opacity(0.06), radius: 16, y: 8)
    }
}

extension View {
    func studioCard(radius: CGFloat = Studio.Radius.card,
                    fill: Color = Studio.Palette.tile,
                    padding: CGFloat = Studio.Spacing.md) -> some View {
        modifier(StudioCard(radius: radius, fill: fill, padding: padding))
    }
}

// MARK: - Stage backdrop

// Layered radial "aurora" over a near-black base. Deliberately uses radial
// gradients (not MeshGradient) so it is rock-solid across configurations.
struct AuroraBackground: View {
    var body: some View {
        ZStack {
            Studio.Palette.stageBase
            RadialGradient(colors: [Studio.Palette.auroraIndigo.opacity(0.45), .clear],
                           center: .topLeading, startRadius: 0, endRadius: 480)
            RadialGradient(colors: [Studio.Palette.auroraViolet.opacity(0.40), .clear],
                           center: .bottomTrailing, startRadius: 0, endRadius: 520)
            RadialGradient(colors: [Studio.Palette.auroraCyan.opacity(0.20), .clear],
                           center: .center, startRadius: 0, endRadius: 360)
        }
        .ignoresSafeArea()
    }
}

extension View {
    /// Dims a screen into the dark "Stage" — the live scoring focus mode.
    func studioStage() -> some View {
        self
            .background(AuroraBackground())
            .preferredColorScheme(.dark)
            .tint(Studio.Palette.auroraViolet)
    }
}

// MARK: - Score ring (Workspace gauges)

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

// MARK: - Stage button styles

struct StagePrimaryButtonStyle: ButtonStyle {
    /// `nil` tint = aurora gradient fill.
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
                        shape.fill(Studio.auroraGradient)
                    }
                }
                .shadow(color: (tint ?? Studio.Palette.auroraViolet).opacity(isEnabled ? 0.5 : 0),
                        radius: configuration.isPressed ? 4 : 14, y: 4)
                .opacity(isEnabled ? (configuration.isPressed ? 0.9 : 1) : 0.4)
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .animation(.snappy(duration: 0.18), value: configuration.isPressed)
        }
    }
}

struct StageSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        StyledLabel(configuration: configuration)
    }

    private struct StyledLabel: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.headline)
                .foregroundStyle(.white.opacity(0.9))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(.ultraThinMaterial,
                            in: RoundedRectangle(cornerRadius: Studio.Radius.chip, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Studio.Radius.chip, style: .continuous)
                        .strokeBorder(.white.opacity(0.12))
                )
                .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.35)
        }
    }
}
