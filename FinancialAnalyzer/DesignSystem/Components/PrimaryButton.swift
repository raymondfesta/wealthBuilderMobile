import SwiftUI

/// Primary CTA button with glow effect
struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    var isDisabled: Bool = false
    var isLoading: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: DesignTokens.Colors.buttonTextPrimary))
                        .scaleEffect(0.8)
                }

                Text(title)
                    .font(.headlineSemibold)
                    .foregroundColor(
                        isDisabled
                            ? DesignTokens.Colors.textSecondary
                            : DesignTokens.Colors.buttonTextPrimary
                    )
                    .tracking(-0.43)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                isDisabled
                    ? DesignTokens.Colors.textSecondary.opacity(0.3)
                    : DesignTokens.Colors.accentPrimary
            )
            .cornerRadius(DesignTokens.CornerRadius.pill)
        }
        .disabled(isDisabled || isLoading)
        .shadow(
            color: (isDisabled || isLoading)
                ? .clear
                : DesignTokens.Shadows.buttonGlowColor,
            radius: DesignTokens.Shadows.buttonGlowRadius,
            x: 0,
            y: 0
        )
        .shadow(
            color: (isDisabled || isLoading)
                ? .clear
                : DesignTokens.Shadows.buttonShadowColor,
            radius: DesignTokens.Shadows.buttonShadowRadius,
            x: 0,
            y: DesignTokens.Shadows.buttonShadowY
        )
    }
}

/// Secondary button with outline style
struct SecondaryButton: View {
    let title: String
    let action: () -> Void
    var isDisabled: Bool = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headlineSemibold)
                .foregroundColor(
                    isDisabled
                        ? DesignTokens.Colors.textSecondary
                        : DesignTokens.Colors.accentPrimary
                )
                .tracking(-0.43)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.pill)
                        .stroke(
                            isDisabled
                                ? DesignTokens.Colors.textSecondary.opacity(0.3)
                                : DesignTokens.Colors.accentPrimary,
                            lineWidth: 1.5
                        )
                )
        }
        .disabled(isDisabled)
    }
}

/// Text button for tertiary actions
struct TextButton: View {
    let title: String
    let action: () -> Void
    var color: Color = DesignTokens.Colors.accentPrimary

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadlineRegular)
                .foregroundColor(color)
                .tracking(-0.23)
        }
        .buttonStyle(.plain)
    }
}

/// Glassmorphic button with translucent background
struct GlassButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadlineRegular)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.xs)
                .background(
                    ZStack {
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
                .background(DesignTokens.Colors.cardBase.opacity(0.6))
                .cornerRadius(DesignTokens.CornerRadius.pill)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.pill)
                        .stroke(DesignTokens.Colors.borderSubtle, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

/// Glassmorphic icon button (circular)
struct GlassIconButton: View {
    let icon: String
    var iconColor: Color = DesignTokens.Colors.textSecondary
    let action: () -> Void
    var size: CGFloat = 44

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(iconColor)
                .frame(width: size, height: size)
                .background(
                    ZStack {
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
                .background(DesignTokens.Colors.cardBase.opacity(0.6))
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(DesignTokens.Colors.borderSubtle, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Buttons") {
    ScrollView {
        VStack(spacing: DesignTokens.Spacing.xl) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text("Primary Button")
                    .captionStyle()

                PrimaryButton(title: "Create my allocation plan") {
                    print("Primary tapped")
                }

                PrimaryButton(title: "Loading state", action: { print("Loading tapped") }, isLoading: true)

                PrimaryButton(title: "Disabled state", action: { print("Disabled tapped") }, isDisabled: true)
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text("Secondary Button")
                    .captionStyle()

                SecondaryButton(title: "View breakdown") {
                    print("Secondary tapped")
                }

                SecondaryButton(title: "Disabled state", isDisabled: true) {
                    print("Disabled tapped")
                }
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text("Text Button")
                    .captionStyle()

                TextButton(title: "Skip for now") {
                    print("Text tapped")
                }

                TextButton(title: "Learn more", color: DesignTokens.Colors.accentSecondary) {
                    print("Text tapped")
                }
            }
        }
        .padding(DesignTokens.Spacing.md)
    }
    .primaryBackgroundGradient()
    .preferredColorScheme(.dark)
}
