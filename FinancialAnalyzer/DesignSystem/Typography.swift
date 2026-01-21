import SwiftUI

// MARK: - Typography
// SF Pro system fonts with precise tracking values

extension Font {
    // Display Styles
    static var displayLarge: Font {
        .system(size: 34, weight: .bold)
    }

    // Headline Styles
    static var headlineSemibold: Font {
        .system(size: 17, weight: .semibold)
    }

    static var headlineRegular: Font {
        .system(size: 17, weight: .regular)
    }

    // Body Styles
    static var bodyRegular: Font {
        .system(size: 17, weight: .regular)
    }

    // Subheadline Styles
    static var subheadlineRegular: Font {
        .system(size: 15, weight: .regular)
    }

    // Caption Styles
    static var captionRegular: Font {
        .system(size: 12, weight: .regular)
    }

    // Title Styles (for values)
    static var titleBold: Font {
        .system(size: 22, weight: .bold)
    }

    // Title 3 (for CTAs)
    static var title3Semibold: Font {
        .system(size: 20, weight: .semibold)
    }
}

// MARK: - Typography View Extensions

extension View {
    /// Display text style - large titles
    func displayStyle(color: Color = DesignTokens.Colors.textPrimary) -> some View {
        self
            .font(.displayLarge)
            .foregroundColor(color)
            .tracking(0.4)
    }

    /// Headline text style - section headers
    func headlineStyle(color: Color = DesignTokens.Colors.textPrimary) -> some View {
        self
            .font(.headlineSemibold)
            .foregroundColor(color)
            .tracking(-0.43)
    }

    /// Body text style - regular content
    func bodyStyle(color: Color = DesignTokens.Colors.textSecondary) -> some View {
        self
            .font(.bodyRegular)
            .foregroundColor(color)
            .tracking(-0.43)
    }

    /// Subheadline text style - secondary content
    func subheadlineStyle(color: Color = DesignTokens.Colors.textSecondary) -> some View {
        self
            .font(.subheadlineRegular)
            .foregroundColor(color)
            .tracking(-0.23)
    }

    /// Caption text style - small labels
    func captionStyle(color: Color = DesignTokens.Colors.textSecondary) -> some View {
        self
            .font(.captionRegular)
            .foregroundColor(color)
    }

    /// Title value style - financial values
    func titleValueStyle(color: Color = DesignTokens.Colors.textEmphasis) -> some View {
        self
            .font(.titleBold)
            .foregroundColor(color)
            .tracking(-0.26)
    }

    /// Title 3 style - CTAs and emphasis
    func title3Style(color: Color = DesignTokens.Colors.textPrimary) -> some View {
        self
            .font(.title3Semibold)
            .foregroundColor(color)
            .tracking(-0.45)
    }
}

// MARK: - Preview

#Preview("Typography") {
    ScrollView {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            Text("Display Large")
                .displayStyle()

            Text("Headline Semibold")
                .headlineStyle()

            Text("Body Regular - This is body text used for general content and descriptions.")
                .bodyStyle()

            Text("Subheadline Regular")
                .subheadlineStyle()

            Text("Caption Regular")
                .captionStyle()

            Text("$22,800")
                .titleValueStyle()

            Text("Title 3 Semibold")
                .title3Style()

            Divider()
                .background(DesignTokens.Colors.divider)

            // Color variants
            Text("Text Primary")
                .bodyStyle(color: DesignTokens.Colors.textPrimary)

            Text("Text Secondary")
                .bodyStyle(color: DesignTokens.Colors.textSecondary)

            Text("Text Tertiary")
                .bodyStyle(color: DesignTokens.Colors.textTertiary)

            Text("Accent Primary")
                .headlineStyle(color: DesignTokens.Colors.accentPrimary)
        }
        .padding(DesignTokens.Spacing.md)
    }
    .primaryBackgroundGradient()
    .preferredColorScheme(.dark)
}
