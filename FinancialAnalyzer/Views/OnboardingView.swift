import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @ObservedObject var viewModel: FinancialViewModel
    @State private var currentPage = 0
    @State private var showAccountsConnected = false

    let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "building.columns.fill",
            title: "Connect Your Bank",
            description: "Securely link your bank accounts using Plaid's trusted platform",
            color: .blue
        ),
        OnboardingPage(
            icon: "chart.bar.fill",
            title: "Automatic Analysis",
            description: "We'll analyze 6 months of transactions and categorize them automatically",
            color: .green
        ),
        OnboardingPage(
            icon: "dollarsign.circle.fill",
            title: "Financial Insights",
            description: "Get a clear picture of your income, expenses, debt, investments, and more",
            color: .purple
        )
    ]

    // Colors from design
    private let bgBase = Color(red: 0.04, green: 0.05, blue: 0.06)
    private let accentLight = Color(red: 0.18, green: 0.75, blue: 0.61)

    var body: some View {
        Group {
            if showAccountsConnected {
                AccountsConnectedView(viewModel: viewModel)
                    .primaryBackgroundGradient()
            } else {
                onboardingContent
            }
        }
        .onChange(of: viewModel.accounts.count) { newCount in
            if newCount > 0 {
                withAnimation {
                    showAccountsConnected = true
                }
            }
        }
    }

    private var onboardingContent: some View {
        VStack {
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    OnboardingPageView(page: page)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            // Connect button
            Button {
                Task {
                    await viewModel.connectBankAccount(from: nil)
                }
            } label: {
                Text("Connect my accounts")
                    .font(.headline)
                    .foregroundColor(bgBase)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(accentLight)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 32)

            // Skip button
            Button("Skip") {
                isPresented = false
            }
            .foregroundColor(.white.opacity(0.7))
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(
            LinearGradient(
                stops: [
                    Gradient.Stop(color: Color(red: 0.04, green: 0.05, blue: 0.06), location: 0.00),
                    Gradient.Stop(color: Color(red: 0.05, green: 0.08, blue: 0.09), location: 0.25),
                    Gradient.Stop(color: Color(red: 0.05, green: 0.07, blue: 0.09), location: 0.45),
                    Gradient.Stop(color: Color(red: 0.06, green: 0.13, blue: 0.11), location: 0.50),
                    Gradient.Stop(color: Color(red: 0.12, green: 0.44, blue: 0.35), location: 0.75),
                    Gradient.Stop(color: Color(red: 0.18, green: 0.75, blue: 0.61), location: 1.00),
                ],
                startPoint: UnitPoint(x: 0.5, y: 1),
                endPoint: UnitPoint(x: 0.5, y: 0)
            )
        )
    }
}

// MARK: - Onboarding Page View

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: page.icon)
                .font(.system(size: 40))
                .foregroundColor(DesignTokens.Colors.accentPrimary)
                .padding(16)
                .primaryCardStyle()

            VStack(spacing: 16) {
                Text(page.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(page.description)
                    .font(.body)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
    }
}

// MARK: - Onboarding Page Model

struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
    let color: Color
}

#Preview {
    OnboardingView(isPresented: .constant(true), viewModel: FinancialViewModel())
        .preferredColorScheme(.dark)
}
