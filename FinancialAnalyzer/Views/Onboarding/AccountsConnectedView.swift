import SwiftUI

/// View shown after accounts are connected but before analysis
struct AccountsConnectedView: View {
    @ObservedObject var viewModel: FinancialViewModel
    @State private var showConnectedAccountsSheet = false

    var body: some View {
        ZStack {
            DesignTokens.Colors.backgroundPrimary
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar with add button
                HStack {
                    Spacer()
                    GlassIconButton(icon: "plus", iconColor: DesignTokens.Colors.accentPrimary) {
                        Task {
                            await viewModel.connectBankAccount(from: nil)
                        }
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.top, DesignTokens.Spacing.xs)

                Spacer()

                // Center content
                VStack(spacing: DesignTokens.Spacing.xs) {
                    // Checkmark icon
                    Image(systemName: "checkmark")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(DesignTokens.Colors.accentPrimary)
                        .padding(.bottom, DesignTokens.Spacing.xs)

                    // Title
                    Text("Accounts connected")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                        .tracking(0.38)

                    // Subtitle
                    Text("You've connected \(viewModel.accounts.count) account\(viewModel.accounts.count == 1 ? "" : "s").")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .tracking(-0.43)
                        .padding(.top, DesignTokens.Spacing.xxs)

                    // Review accounts link
                    Button {
                        showConnectedAccountsSheet = true
                    } label: {
                        HStack(spacing: DesignTokens.Spacing.xs) {
                            Image(systemName: "eye")
                                .font(.system(size: 17, weight: .medium))
                            Text("Review connected accounts")
                                .font(.system(size: 17, weight: .semibold))
                                .tracking(-0.43)
                        }
                        .foregroundColor(DesignTokens.Colors.accentPrimary)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, DesignTokens.Spacing.lg)
                }
                .padding(.horizontal, DesignTokens.Spacing.md)

                Spacer()

                // Bottom section
                VStack(spacing: DesignTokens.Spacing.md) {
                    // Primary CTA
                    PrimaryButton(title: "Analyze my transactions") {
                        Task {
                            await viewModel.analyzeMyFinances()
                        }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.md)

                    // Caption text
                    Text("We'll analyze your transactions, account balances and show you a detailed breakdown of your monthly money flow and your financial health.")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .tracking(0.06)
                        .lineSpacing(0)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 269)
                }
                .padding(.bottom, DesignTokens.Spacing.xxxl)
            }
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
