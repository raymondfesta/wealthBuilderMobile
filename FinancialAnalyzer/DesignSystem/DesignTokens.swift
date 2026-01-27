import SwiftUI

// MARK: - Design Tokens
// Swiss Precision dark theme design system

struct DesignTokens {

    // MARK: - Colors

    struct Colors {
        // Background Colors
        static let backgroundPrimary = Color(red: 11/255, green: 13/255, blue: 16/255)
        static let backgroundSecondary = Color(red: 18/255, green: 23/255, blue: 42/255)

        // Card Colors
        static let cardBase = Color(red: 18/255, green: 21/255, blue: 28/255)
        static let cardOverlay1 = Color(red: 20/255, green: 24/255, blue: 35/255)
        static let cardOverlay2 = Color(red: 16/255, green: 19/255, blue: 26/255)

        // Text Colors
        static let textPrimary = Color(red: 230/255, green: 234/255, blue: 240/255)
        static let textSecondary = Color(red: 154/255, green: 164/255, blue: 178/255)
        static let textTertiary = Color(red: 182/255, green: 188/255, blue: 201/255)
        static let textEmphasis = Color(red: 245/255, green: 247/255, blue: 250/255)

        // Accent Colors
        static let accentPrimary = Color(red: 47/255, green: 191/255, blue: 156/255)    // #2fbf9c
        static let accentSecondary = Color(red: 77/255, green: 163/255, blue: 199/255)  // #4da3c7

        // Semantic Colors (from existing ColorPalette)
        static let progressGreen = Color(red: 52/255, green: 199/255, blue: 89/255)     // #34C759
        static let stableBlue = Color(red: 0/255, green: 122/255, blue: 255/255)        // #007AFF
        static let opportunityOrange = Color(red: 255/255, green: 149/255, blue: 0/255) // #FF9500
        static let protectionMint = Color(red: 0/255, green: 199/255, blue: 190/255)    // #00C7BE
        static let wealthPurple = Color(red: 175/255, green: 82/255, blue: 222/255)     // #AF52DE

        // Border & Divider Colors
        static let borderSubtle = Color.white.opacity(0.04)
        static let borderLight = Color.white.opacity(0.05)
        static let borderMedium = Color.white.opacity(0.06)
        static let divider = Color.white.opacity(0.06)

        // Glassmorphic Overlay Colors
        static let glassOverlayTop = Color.white.opacity(0.06)
        static let glassOverlayMid = Color.white.opacity(0.02)
        static let glassOverlayBottom = Color.white.opacity(0)
        static let glassInnerStroke = Color.white.opacity(0.05)
    }

    // MARK: - Spacing (8px Grid)

    struct Spacing {
        static let xxs: CGFloat = 4   // 0.5 grid units
        static let xs: CGFloat = 8    // 1 grid unit
        static let sm: CGFloat = 12   // 1.5 grid units
        static let md: CGFloat = 16   // 2 grid units
        static let lg: CGFloat = 20   // 2.5 grid units
        static let xl: CGFloat = 24   // 3 grid units
        static let xxl: CGFloat = 32  // 4 grid units
        static let xxxl: CGFloat = 40 // 5 grid units
    }

    // MARK: - Corner Radius

    struct CornerRadius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 14
        static let xl: CGFloat = 16
        static let pill: CGFloat = 1000
    }

    // MARK: - Shadows

    struct Shadows {
        // Card Shadows
        static let cardPrimaryColor = Color.black.opacity(0.25)
        static let cardPrimaryRadius: CGFloat = 12
        static let cardPrimaryY: CGFloat = 10

        static let cardSecondaryColor = Color.black.opacity(0.25)
        static let cardSecondaryRadius: CGFloat = 2
        static let cardSecondaryY: CGFloat = 4

        // Button Glow
        static let buttonGlowColor = Color(red: 47/255, green: 191/255, blue: 156/255).opacity(0.35)
        static let buttonGlowRadius: CGFloat = 12

        static let buttonShadowColor = Color.black.opacity(0.2)
        static let buttonShadowRadius: CGFloat = 8
        static let buttonShadowY: CGFloat = 6
    }
}

// MARK: - View Extensions

extension View {
    /// Apply glassmorphic card styling with gradients, borders, and shadows
    func primaryCardStyle() -> some View {
        self
            .background(
                ZStack {
                    // Base gradient
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: DesignTokens.Colors.cardOverlay1.opacity(0), location: 0),
                            .init(color: DesignTokens.Colors.cardOverlay2.opacity(0.032), location: 1)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    // Glass overlay
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: DesignTokens.Colors.glassOverlayTop, location: 0),
                            .init(color: DesignTokens.Colors.glassOverlayMid, location: 0.35),
                            .init(color: DesignTokens.Colors.glassOverlayBottom, location: 1)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .blendMode(.screen)
                }
            )
            .background(DesignTokens.Colors.cardBase)
            .cornerRadius(DesignTokens.CornerRadius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                    .stroke(DesignTokens.Colors.borderSubtle, lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                    .strokeBorder(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                DesignTokens.Colors.glassInnerStroke,
                                Color.clear
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: DesignTokens.Shadows.cardPrimaryColor,
                radius: DesignTokens.Shadows.cardPrimaryRadius,
                x: 0,
                y: DesignTokens.Shadows.cardPrimaryY
            )
            .shadow(
                color: DesignTokens.Shadows.cardSecondaryColor,
                radius: DesignTokens.Shadows.cardSecondaryRadius,
                x: 0,
                y: DesignTokens.Shadows.cardSecondaryY
            )
    }

    /// Apply primary background color
    func primaryBackgroundGradient() -> some View {
        self.background(
            DesignTokens.Colors.backgroundPrimary
                .ignoresSafeArea()
        )
    }
}

// MARK: - Preview

#Preview("Design Tokens") {
    ScrollView {
        VStack(spacing: DesignTokens.Spacing.xl) {
            // Colors Preview
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                Text("Colors")
                    .font(.headline)
                    .foregroundColor(DesignTokens.Colors.textPrimary)

                HStack(spacing: DesignTokens.Spacing.xs) {
                    colorSwatch(DesignTokens.Colors.accentPrimary, "Accent")
                    colorSwatch(DesignTokens.Colors.progressGreen, "Green")
                    colorSwatch(DesignTokens.Colors.stableBlue, "Blue")
                    colorSwatch(DesignTokens.Colors.opportunityOrange, "Orange")
                    colorSwatch(DesignTokens.Colors.wealthPurple, "Purple")
                }
            }

            // Card Preview
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text("Sample Card")
                    .font(.headline)
                    .foregroundColor(.white)

                Text("This is body text inside a glassmorphic card.")
                    .font(.subheadline)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            .padding(DesignTokens.Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .primaryCardStyle()
        }
        .padding(DesignTokens.Spacing.md)
    }
    .primaryBackgroundGradient()
    .preferredColorScheme(.dark)
}

@ViewBuilder
private func colorSwatch(_ color: Color, _ name: String) -> some View {
    VStack(spacing: 4) {
        RoundedRectangle(cornerRadius: 8)
            .fill(color)
            .frame(width: 50, height: 50)
        Text(name)
            .font(.caption2)
            .foregroundColor(DesignTokens.Colors.textSecondary)
    }
}
