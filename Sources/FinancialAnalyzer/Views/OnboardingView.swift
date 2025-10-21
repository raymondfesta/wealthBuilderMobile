import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0

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

    var body: some View {
        VStack {
            // Skip button
            HStack {
                Spacer()
                Button("Skip") {
                    isPresented = false
                }
                .padding()
            }

            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    OnboardingPageView(page: page)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            // Continue/Get Started button
            Button {
                if currentPage < pages.count - 1 {
                    withAnimation {
                        currentPage += 1
                    }
                } else {
                    isPresented = false
                }
            } label: {
                Text(currentPage == pages.count - 1 ? "Get Started" : "Continue")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
    }
}

// MARK: - Onboarding Page View

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: page.icon)
                .font(.system(size: 80))
                .foregroundColor(page.color)

            VStack(spacing: 16) {
                Text(page.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(page.description)
                    .font(.body)
                    .foregroundColor(.secondary)
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
