//
//  StudioTokens.swift
//  InterviewIQ
//
//  "Studio" design system — a single, cohesive LIGHT language applied across
//  every screen and modal: calm grouped canvases, soft white cards, one indigo
//  accent (with a subtle indigo→violet gradient for primary actions), and a
//  shared score colour ramp used as both a tint and a fill.
//
//  Colours reuse the existing brand palette in Color+Brand.swift so this is
//  additive, not a fork. iOS 26-native throughout.
//

import SwiftUI

enum Studio {

    // MARK: - Spacing (8pt base grid)
    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs:  CGFloat = 8
        static let sm:  CGFloat = 12
        static let md:  CGFloat = 16
        static let lg:  CGFloat = 24
        static let xl:  CGFloat = 32
    }

    // MARK: - Corner radii (continuous / squircle)
    enum Radius {
        static let chip: CGFloat = 14
        static let card: CGFloat = 20
        static let hero: CGFloat = 28
    }

    // MARK: - Palette
    enum Palette {
        static let accent    = Color.brandPurple                       // #4F46E5 indigo (existing brand)
        static let accentAlt = Color(red: 139/255, green: 92/255, blue: 246/255) // #8B5CF6 violet (gradient partner)

        static let canvas = Color(red: 239/255, green: 240/255, blue: 249/255) // #EFF0F9 branded off-white (not stock grey)
        static let tile   = Color.white                                        // cards pop on the tinted canvas
        static let fill   = Color(.tertiarySystemFill)                // inset controls (unselected pills, fields)

        // Score ramp — single channel, reused as a tint (washes) and a fill (spines/rings)
        static let scoreHigh = Color.successText                       // #10B981 mint (existing)
        static let scoreMid  = Color(red: 245/255, green: 158/255, blue: 11/255) // #F59E0B amber
        static let scoreLow  = Color.systemAlertText                   // #EF4444 rose (existing)
    }

    // MARK: - Score → colour
    // Single source of truth for the 80 / 60 thresholds previously duplicated
    // in DashboardView and CandidateListView.
    static func scoreColor(for score: Int) -> Color {
        switch score {
        case 80...:   return Palette.scoreHigh
        case 60..<80: return Palette.scoreMid
        default:      return Palette.scoreLow
        }
    }

    // MARK: - Monochromatic contextual wash (score tinting)
    // A faint wash of the score colour over a surface — never a saturated fill.
    static func scoreTint(for score: Int,
                          over surface: Color = Palette.tile,
                          amount: Double = 0.10) -> Color {
        surface.mix(with: scoreColor(for: score), by: amount)
    }

    // MARK: - Accent gradient (primary actions, progress) — premium without going dark
    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [Palette.accent, Palette.accentAlt],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Signature typography
extension Font {
    /// Rounded display face — InterviewIQ's signature heading type, distinct
    /// from the stock SF used by system apps like Settings.
    static func studioDisplay(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}
