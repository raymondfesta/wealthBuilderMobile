import SwiftUI

/// View shown after accounts are connected but before analysis
struct AccountsConnectedView: View {
    @ObservedObject var viewModel: FinancialViewModel
    @State private var showConnectedAccountsSheet = false

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xxl) {
            Spacer()

            // Success message
            VStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(DesignTokens.Colors.progressGreen)

                Text("Accounts Connected!")
                    .displayStyle()

                Text("You've connected \(viewModel.accounts.count) account\(viewModel.accounts.count == 1 ? "" : "s")")
                    .bodyStyle()

                // View Connected Accounts button
                TextButton(title: "View Connected Accounts", color: DesignTokens.Colors.accentSecondary) {
                    showConnectedAccountsSheet = true
                }
                .padding(.top, DesignTokens.Spacing.xs)
            }

            Spacer()

            // Next step section
            VStack(spacing: DesignTokens.Spacing.lg) {
                VStack(spacing: DesignTokens.Spacing.sm) {
                    Text("Ready for the next step?")
                        .headlineStyle()

                    Text("We'll analyze your transactions and identify spending patterns")
                        .subheadlineStyle()
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DesignTokens.Spacing.xxl)
                }

                // Action buttons
                VStack(spacing: DesignTokens.Spacing.sm) {
                    // Primary CTA - Analyze Transactions
                    PrimaryButton(title: "Analyze My Transactions") {
                        Task {
                            await viewModel.analyzeMyFinances()
                        }
                    }

                    // Secondary CTA - Connect Another Account
                    SecondaryButton(title: "Connect Another Account") {
                        Task {
                            await viewModel.connectBankAccount(from: nil)
                        }
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.xxl)
            }
            .padding(.bottom, DesignTokens.Spacing.xxl)
        }
        .sheet(isPresented: $showConnectedAccountsSheet) {
            ConnectedAccountsSheet(viewModel: viewModel)
        }
    }
}

#if DEBUG
struct AccountsConnectedView_Previews: PreviewProvider {
    static var previews: some View {
        AccountsConnectedView(viewModel: FinancialViewModel())
            .primaryBackgroundGradient()
    }
}
#endif
