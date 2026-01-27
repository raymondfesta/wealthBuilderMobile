import SwiftUI

/// Initial welcome screen shown when no accounts are connected
struct WelcomeConnectView: View {
    @ObservedObject var viewModel: FinancialViewModel

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            Spacer()

            Image(systemName: "chart.pie.fill")
                .font(.system(size: 80))
                .foregroundColor(DesignTokens.Colors.stableBlue)

            VStack(spacing: DesignTokens.Spacing.sm) {
                Text(viewModel.userJourneyState.title)
                    .displayStyle()

                Text(viewModel.userJourneyState.description)
                    .bodyStyle()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignTokens.Spacing.xxl)
            }

            PrimaryButton(title: viewModel.userJourneyState.nextActionTitle) {
                Task {
                    await viewModel.connectBankAccount(from: nil)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.xxl)
            .padding(.top, DesignTokens.Spacing.xl)

            Spacer()
        }
    }
}

#if DEBUG
struct WelcomeConnectView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeConnectView(viewModel: FinancialViewModel())
            .primaryBackgroundGradient()
    }
}
#endif
