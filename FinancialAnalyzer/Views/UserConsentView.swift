import SwiftUI

struct UserConsentView: View {
    @Binding var hasConsented: Bool
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Financial Data Access")
                        .font(.largeTitle.bold())

                    Text("Before connecting your bank accounts, please review what data we'll access and how it's used.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }

                Divider()

                // What we access
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Account balances and transactions", systemImage: "dollarsign.circle.fill")
                        Label("Account names and types", systemImage: "building.columns.fill")
                        Label("Last 6 months of transaction history", systemImage: "calendar")
                        Label("Account holder information", systemImage: "person.fill")
                    }
                } label: {
                    Text("We Will Access:")
                        .font(.headline)
                }

                // How we use it
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Financial analysis and insights", systemImage: "chart.line.uptrend.xyaxis")
                        Label("Budget recommendations", systemImage: "target")
                        Label("AI-powered spending guidance", systemImage: "sparkles")
                        Label("Transaction categorization", systemImage: "tag.fill")
                    }
                } label: {
                    Text("How We Use It:")
                        .font(.headline)
                }

                // How we protect it
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Encrypted storage (iOS Keychain)", systemImage: "lock.shield.fill")
                            .foregroundColor(.green)
                        Label("Local processing only", systemImage: "iphone")
                            .foregroundColor(.green)
                        Label("Never sold or shared", systemImage: "hand.raised.fill")
                            .foregroundColor(.green)
                        Label("AI sees anonymized summaries only", systemImage: "eye.slash.fill")
                            .foregroundColor(.orange)
                    }
                } label: {
                    Text("How We Protect It:")
                        .font(.headline)
                }

                // Third party services
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("• **Plaid**: Securely connects to your bank (plaid.com/legal)")
                        Text("• **OpenAI**: Analyzes spending patterns (receives $ amounts only, not merchant names or personal info)")
                    }
                    .font(.footnote)
                } label: {
                    Text("Third-Party Services:")
                        .font(.headline)
                }

                // Privacy policy link
                NavigationLink(destination: PrivacyPolicyView()) {
                    Label("Read Full Privacy Policy", systemImage: "doc.text")
                        .font(.subheadline)
                }
                .padding(.vertical, 8)

                // Consent button
                Button(action: {
                    hasConsented = true
                    UserDefaults.standard.set(true, forKey: "user_consent_given")
                    UserDefaults.standard.set(Date(), forKey: "user_consent_date")
                    dismiss()
                }) {
                    Text("I Understand & Agree")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.top)

                Text("You can delete your data anytime from Settings")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .padding()
        }
        .navigationTitle("Data Consent")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        UserConsentView(hasConsented: .constant(false))
    }
}
