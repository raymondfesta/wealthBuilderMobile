import SwiftUI

/// Design system color palette for Financial Health features
/// Colors chosen to be encouraging, non-judgmental, and opportunity-focused
extension Color {

    // MARK: - Progress & Growth (Green)
    // Use for: Savings, positive trends, milestones achieved
    // Psychology: Natural, positive, growth-oriented

    static let progressGreen = Color(hex: "#34C759")
    static let growthGreen = Color(hex: "#30D158")

    // MARK: - Stability & Trust (Blue)
    // Use for: Emergency fund, income stability, protection metrics
    // Psychology: Calm, reliable, secure

    static let stableBlue = Color(hex: "#007AFF")
    static let trustBlue = Color(hex: "#0A84FF")

    // MARK: - Opportunity & Action (Orange)
    // Use for: Discretionary spending, opportunities to improve, action items
    // Psychology: Warm, energetic, actionable

    static let opportunityOrange = Color(hex: "#FF9500")
    static let actionOrange = Color(hex: "#FF9F0A")

    // MARK: - Protection & Safety (Mint/Teal)
    // Use for: Cash flow, liquidity, safety net concepts
    // Psychology: Fresh, flowing, calm security

    static let protectionMint = Color(hex: "#00C7BE")
    static let safetyTeal = Color(hex: "#5AC8FA")

    // MARK: - Wealth & Premium (Purple)
    // Use for: Investments, wealth building, aspirational goals
    // Psychology: Premium, aspirational, long-term thinking

    static let wealthPurple = Color(hex: "#AF52DE")
    static let premiumPurple = Color(hex: "#BF5AF2")

    // MARK: - Neutral Tones
    // Use for: Backgrounds, secondary text, borders

    static let neutralGray = Color(hex: "#8E8E93")
    static let lightGray = Color(hex: "#C7C7CC")

    // MARK: - Usage Guidelines

    /*
     COLOR THEORY FOR FINANCIAL HEALTH:

     ✅ DO USE:
     - Green for savings, growth, and positive progress
     - Blue for stability, security, and trust
     - Orange for opportunities and actionable insights
     - Mint/Teal for cash flow and liquidity
     - Purple for investments and wealth building

     ⚠️ USE SPARINGLY:
     - Red ONLY in debt contexts and reframe as "opportunity to improve"
     - Avoid red for warnings or negative states
     - If using red, pair with encouraging language

     METRIC → COLOR MAPPINGS:
     - Monthly Savings: Green (growth metaphor)
     - Emergency Fund: Blue (stability/protection)
     - Income: Mint (fresh/flowing)
     - Debt Payments: Orange (opportunity to improve, not warning)
     - Discretionary Spending: Orange (choice/flexibility)
     - Investments: Purple (wealth building)

     VISUAL HIERARCHY:
     - Primary actions: Blue (trust-building)
     - Positive metrics: Green (encouragement)
     - Neutral info: Gray (non-judgmental)
     - Avoid: Red/Yellow for status indicators (too judgmental)

     ACCESSIBILITY:
     - All colors meet WCAG AA contrast requirements
     - Don't rely on color alone for meaning
     - Include icons and text labels
     */

    // Note: hex initializer is provided by ColorExtensions.swift
}

// MARK: - Preview Provider

#if DEBUG
struct ColorPalette_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Financial Health Color Palette")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding()

                ColorSection(
                    title: "Progress & Growth",
                    subtitle: "Savings, positive trends",
                    colors: [
                        ("Progress Green", Color.progressGreen),
                        ("Growth Green", Color.growthGreen)
                    ]
                )

                ColorSection(
                    title: "Stability & Trust",
                    subtitle: "Emergency fund, security",
                    colors: [
                        ("Stable Blue", Color.stableBlue),
                        ("Trust Blue", Color.trustBlue)
                    ]
                )

                ColorSection(
                    title: "Opportunity & Action",
                    subtitle: "Discretionary, opportunities",
                    colors: [
                        ("Opportunity Orange", Color.opportunityOrange),
                        ("Action Orange", Color.actionOrange)
                    ]
                )

                ColorSection(
                    title: "Protection & Safety",
                    subtitle: "Cash flow, liquidity",
                    colors: [
                        ("Protection Mint", Color.protectionMint),
                        ("Safety Teal", Color.safetyTeal)
                    ]
                )

                ColorSection(
                    title: "Wealth & Premium",
                    subtitle: "Investments, aspirational",
                    colors: [
                        ("Wealth Purple", Color.wealthPurple),
                        ("Premium Purple", Color.premiumPurple)
                    ]
                )
            }
            .padding()
        }
    }

    struct ColorSection: View {
        let title: String
        let subtitle: String
        let colors: [(String, Color)]

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 12) {
                    ForEach(colors, id: \.0) { name, color in
                        VStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(color)
                                .frame(height: 80)

                            Text(name)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
        }
    }
}
#endif
