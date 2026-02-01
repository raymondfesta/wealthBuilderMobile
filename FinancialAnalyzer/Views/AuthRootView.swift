import SwiftUI

struct AuthRootView: View {
    @StateObject private var authService = AuthService.shared

    var body: some View {
        Group {
            switch authService.authState {
            case .loading:
                LoadingView()

            case .unauthenticated:
                LoginView(authService: authService)

            case .authenticated:
                MainAppView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authService.authState)
    }
}

private struct LoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            ProgressView()
                .scaleEffect(1.2)

            Text("Loading...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

struct MainAppView: View {
    @ObservedObject private var authService = AuthService.shared
    @StateObject private var viewModel = FinancialViewModel()
    @State private var showOnboarding = false

    var body: some View {
        Group {
            if showOnboarding {
                OnboardingView(isPresented: $showOnboarding, viewModel: viewModel)
            } else {
                ContentView()
            }
        }
        .onAppear {
            if authService.isNewRegistration {
                showOnboarding = true
                authService.clearNewRegistrationFlag()
            }
        }
    }
}

#Preview {
    AuthRootView()
}
