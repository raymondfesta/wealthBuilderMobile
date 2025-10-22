import SwiftUI

/// Full-screen loading overlay with step-by-step progress messages
struct LoadingOverlay: View {
    let currentStep: LoadingStep
    let isVisible: Bool

    var body: some View {
        ZStack {
            if isVisible {
                // Semi-transparent background
                Color.black.opacity(0.4)
                    .ignoresSafeArea()

                // Loading card
                VStack(spacing: 24) {
                    // Animated spinner
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.blue)

                    // Step indicator
                    VStack(spacing: 8) {
                        Text(currentStep.title)
                            .font(.headline)
                            .fontWeight(.semibold)

                        Text(currentStep.message)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    // Progress indicator
                    HStack(spacing: 8) {
                        ForEach(LoadingStep.allSteps.indices, id: \.self) { index in
                            Circle()
                                .fill(index <= currentStep.stepNumber ? Color.blue : Color.gray.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                }
                .padding(32)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
                )
                .padding(.horizontal, 40)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isVisible)
        .animation(.easeInOut(duration: 0.2), value: currentStep)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.gray.opacity(0.2)
            .ignoresSafeArea()

        VStack(spacing: 20) {
            Text("Background Content")
                .font(.title)

            Button("Sample Button") {}
                .buttonStyle(.borderedProminent)
        }

        LoadingOverlay(currentStep: .analyzingTransactions(count: 247), isVisible: true)
    }
}
