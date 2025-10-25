import SwiftUI

/// Empty state shown when health report hasn't been set up yet
/// Explains value and guides user to setup flow
struct HealthReportEmptyStateView: View {
    let onSetup: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header Icon
                Image(systemName: "chart.bar.doc.horizontal.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.stableBlue, .progressGreen],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .padding(.top, 40)

                // Headline
                VStack(spacing: 12) {
                    Text("Unlock Your Financial Health Report")
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    Text("Get personalized insights that help you make better financial decisions")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                // Value Props (3 cards)
                VStack(spacing: 16) {
                    ValuePropCard(
                        icon: "shield.lefthalf.filled",
                        iconColor: .stableBlue,
                        title: "Track Emergency Fund Coverage",
                        description: "Know exactly how many months of protection you have"
                    )

                    ValuePropCard(
                        icon: "chart.line.uptrend.xyaxis",
                        iconColor: .progressGreen,
                        title: "Monitor Savings Rate",
                        description: "See your progress toward financial goals over time"
                    )

                    ValuePropCard(
                        icon: "dollarsign.circle.fill",
                        iconColor: .protectionMint,
                        title: "Understand Income Stability",
                        description: "Get recommendations tailored to your income pattern"
                    )
                }
                .padding(.horizontal, 24)

                // Explanation
                VStack(spacing: 12) {
                    Text("Why We Need Your Help")
                        .font(.headline)

                    Text("To calculate accurate metrics, we need you to tag a few accounts. This helps us identify your emergency fund and understand your financial structure.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()

                // CTAs
                VStack(spacing: 12) {
                    // Primary CTA
                    Button {
                        onSetup()
                    } label: {
                        Label("Set Up Health Report", systemImage: "arrow.right.circle.fill")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.stableBlue)
                            .cornerRadius(16)
                    }

                    // Secondary action
                    Button {
                        onDismiss()
                    } label: {
                        Text("I'll do this later")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }
}

// MARK: - Value Prop Card

struct ValuePropCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(iconColor)
                .frame(width: 50, height: 50)
                .background(
                    Circle()
                        .fill(iconColor.opacity(0.1))
                )

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Preview

#if DEBUG
struct HealthReportEmptyStateView_Previews: PreviewProvider {
    static var previews: some View {
        HealthReportEmptyStateView(
            onSetup: { print("Setup tapped") },
            onDismiss: { print("Dismiss tapped") }
        )
    }
}
#endif
