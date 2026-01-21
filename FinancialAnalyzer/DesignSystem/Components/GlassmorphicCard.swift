import SwiftUI

/// Glassmorphic card component with optional header
struct GlassmorphicCard<Content: View>: View {
    let title: String?
    let subtitle: String?
    let showDivider: Bool
    let content: Content

    init(
        title: String? = nil,
        subtitle: String? = nil,
        showDivider: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.showDivider = showDivider
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            // Card Header (if provided)
            if let title = title {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    Text(title)
                        .headlineStyle(color: .white)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .captionStyle()
                    }
                }

                if showDivider {
                    Rectangle()
                        .fill(DesignTokens.Colors.divider)
                        .frame(height: 1)
                }
            }

            // Card Content
            content
        }
        .padding(DesignTokens.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .primaryCardStyle()
    }
}

// MARK: - Preview

#Preview("GlassmorphicCard") {
    ScrollView {
        VStack(spacing: DesignTokens.Spacing.lg) {
            GlassmorphicCard(
                title: "Your Financial Position",
                subtitle: "A real-time snapshot of where your money stands today."
            ) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("Emergency Fund")
                        .bodyStyle()
                    Text("$22,800")
                        .titleValueStyle()
                }
            }

            GlassmorphicCard(
                title: "Monthly Flow",
                showDivider: false
            ) {
                VStack(spacing: DesignTokens.Spacing.xs) {
                    HStack {
                        Text("Income")
                            .bodyStyle()
                        Spacer()
                        Text("$5,000")
                            .headlineStyle(color: DesignTokens.Colors.progressGreen)
                    }
                    HStack {
                        Text("Expenses")
                            .bodyStyle()
                        Spacer()
                        Text("$3,200")
                            .headlineStyle(color: DesignTokens.Colors.opportunityOrange)
                    }
                }
            }

            GlassmorphicCard {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("Card without title")
                        .headlineStyle()
                    Text("This card has no header section.")
                        .bodyStyle()
                }
            }
        }
        .padding(DesignTokens.Spacing.md)
    }
    .primaryBackgroundGradient()
    .preferredColorScheme(.dark)
}
