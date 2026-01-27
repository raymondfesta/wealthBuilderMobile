import SwiftUI

struct WelcomePageView: View {
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            VStack(spacing: DesignTokens.Spacing.xxxl) {
                Spacer()

                // Icon/Logo area
                VStack(spacing: DesignTokens.Spacing.md) {
                    Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                        .font(.system(size: 100))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [DesignTokens.Colors.accentPrimary, DesignTokens.Colors.accentSecondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text("CAPIUM")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .tracking(4)
                        .foregroundColor(DesignTokens.Colors.accentPrimary)
                }
                .padding(.bottom, DesignTokens.Spacing.lg)

                // Main content
                VStack(spacing: DesignTokens.Spacing.xl) {
                    // Heading
                    Text("Tired of managing your personal finances?")
                        .displayStyle()
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, DesignTokens.Spacing.xxl)

                    // Description
                    Text("Join Capium. Sophisticated income allocation and wealth management for high-income earners.")
                        .bodyStyle()
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .padding(.horizontal, DesignTokens.Spacing.xxxl)
                }

                Spacer()

                // Call to action button
                PrimaryButton(title: "Join for free") {
                    isPresented = true
                }
                .padding(.horizontal, DesignTokens.Spacing.xxl)
                .padding(.bottom, DesignTokens.Spacing.xxxl)
            }
        }
        .primaryBackgroundGradient()
        .preferredColorScheme(.dark)
    }
}

#Preview {
    WelcomePageView(isPresented: .constant(true))
}
