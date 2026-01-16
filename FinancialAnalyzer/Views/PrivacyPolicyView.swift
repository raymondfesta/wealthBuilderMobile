import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Privacy Policy")
                    .font(.title.bold())

                Section {
                    Text("Last Updated: \(Date().formatted(date: .long, time: .omitted))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()

                PolicySection(
                    title: "What Information We Collect",
                    icon: "info.circle.fill",
                    content: """
                    When you connect your bank accounts via Plaid, we collect:
                    • Bank account names, types, and balances
                    • Transaction history (last 6 months)
                    • Transaction amounts, dates, and merchant names
                    • Account holder name and email (if provided by bank)
                    """
                )

                PolicySection(
                    title: "How We Use Your Information",
                    icon: "gearshape.fill",
                    content: """
                    We use your financial data to:
                    • Calculate financial health metrics
                    • Generate personalized budget recommendations
                    • Provide AI-powered spending insights
                    • Track progress toward financial goals
                    • Categorize transactions automatically
                    """
                )

                PolicySection(
                    title: "How We Store Your Information",
                    icon: "lock.shield.fill",
                    content: """
                    Your data is stored securely:
                    • Access tokens encrypted in iOS Keychain
                    • Transaction data cached locally on your device
                    • Backend server runs locally on YOUR computer
                    • No cloud storage or remote servers
                    • Data never leaves your local network
                    """
                )

                PolicySection(
                    title: "Third-Party Services",
                    icon: "network",
                    content: """
                    We use the following third-party services:

                    **Plaid**: Securely connects to your bank
                    • Privacy Policy: plaid.com/legal
                    • They see: Your bank credentials (encrypted)
                    • We receive: Account data and transactions

                    **OpenAI**: AI-powered financial insights
                    • Privacy Policy: openai.com/policies/privacy-policy
                    • They see: Anonymized spending summaries ($amounts, categories)
                    • They DON'T see: Merchant names, personal info, account details
                    """
                )

                PolicySection(
                    title: "Your Rights",
                    icon: "hand.raised.fill",
                    content: """
                    You have full control over your data:
                    • View all stored data anytime
                    • Remove bank connections at any time
                    • Delete all data via Settings → Clear Data
                    • Data is deleted immediately and permanently
                    • No backups are created
                    """
                )

                PolicySection(
                    title: "Data Retention",
                    icon: "clock.fill",
                    content: """
                    • Transaction data: Kept until you delete it
                    • Access tokens: Kept until you remove account
                    • Cache data: Cleared when app is deleted
                    • No automatic backups or cloud sync
                    """
                )

                PolicySection(
                    title: "Security Measures",
                    icon: "checkmark.shield.fill",
                    content: """
                    We protect your data with:
                    • iOS Keychain encryption for sensitive tokens
                    • HTTPS connections to Plaid servers
                    • No logging of sensitive information
                    • Local-only processing (no remote servers)
                    • Rate-limited API calls
                    """
                )

                PolicySection(
                    title: "Personal Use Only",
                    icon: "exclamationmark.triangle.fill",
                    content: """
                    This app is designed for personal financial management:
                    • Not intended for commercial use
                    • Not a substitute for professional financial advice
                    • No warranty or guarantee of accuracy
                    • Use at your own discretion
                    """
                )

                PolicySection(
                    title: "Contact & Questions",
                    icon: "envelope.fill",
                    content: """
                    This is a personal development project.
                    For questions or concerns, check the source code repository or contact the developer directly.
                    """
                )

                Text("By using this app, you acknowledge that you have read and understood this Privacy Policy.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
                    .padding(.top)
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PolicySection: View {
    let title: String
    let icon: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundColor(.blue)

            Text(content)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationView {
        PrivacyPolicyView()
    }
}
