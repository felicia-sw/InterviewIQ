//
//  StudioTokens.swift
//  InterviewIQ
//
//  "Studio" design system — one token spine, two states:
//    • Workspace (light, bento + ledger) for browsing & comparison
//    • Stage (dark, aurora glass) for the live scoring focus moment
//
//  Everything here is iOS 26-native. Colours reuse the existing brand
//  palette in Color+Brand.swift so this is additive, not a fork.
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
        static let accent = Color.brandPurple                       // #4F46E5 (existing brand)
        static let canvas = Color(.systemGroupedBackground)         // Workspace background
        static let tile   = Color(.secondarySystemGroupedBackground)// Workspace tiles

        // Score ramp — single channel, reused as a tint (Workspace) and a glow (Stage)
        static let scoreHigh = Color.successText                    // #10B981 mint (existing)
        static let scoreMid  = Color(red: 245/255, green: 158/255, blue: 11/255)  // #F59E0B amber
        static let scoreLow  = Color.systemAlertText                // #EF4444 rose (existing)

        // Stage (dark aurora)
        static let stageBase    = Color(red: 12/255,  green: 14/255,  blue: 22/255)  // #0C0E16
        static let stageRaise   = Color(red: 20/255,  green: 24/255,  blue: 38/255)  // #141826
        static let auroraIndigo = Color(red: 79/255,  green: 70/255,  blue: 229/255) // #4F46E5
        static let auroraViolet = Color(red: 139/255, green: 92/255,  blue: 246/255) // #8B5CF6
        static let auroraCyan   = Color(red: 34/255,  green: 211/255, blue: 238/255) // #22D3EE
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

    // MARK: - Monochromatic contextual wash (Workspace tinting)
    // A faint wash of the score colour over a surface — never a saturated fill.
    static func scoreTint(for score: Int,
                          over surface: Color = Palette.tile,
                          amount: Double = 0.10) -> Color {
        surface.mix(with: scoreColor(for: score), by: amount)
    }

    // MARK: - Aurora gradient (Stage accents)
    static var auroraGradient: LinearGradient {
        LinearGradient(
            colors: [Palette.auroraIndigo, Palette.auroraViolet, Palette.auroraCyan],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
