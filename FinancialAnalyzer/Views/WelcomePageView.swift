import SwiftUI

struct WelcomePageView: View {
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.05)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Icon/Logo area
                VStack(spacing: 16) {
                    Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                        .font(.system(size: 100))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text("CAPIUM")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .tracking(4)
                        .foregroundColor(.blue)
                }
                .padding(.bottom, 20)

                // Main content
                VStack(spacing: 24) {
                    // Heading
                    Text("Tired of managing your personal finances?")
                        .font(.system(size: 32, weight: .bold))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 32)

                    // Description
                    Text("Join Capium. Sophisticated income allocation and wealth management for high-income earners.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .padding(.horizontal, 40)
                }

                Spacer()

                // Call to action button
                Button {
                    isPresented = false
                } label: {
                    HStack(spacing: 12) {
                        Text("Join for free")
                            .font(.headline)
                            .fontWeight(.semibold)

                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 20))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: [.blue, .blue.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 50)
            }
        }
    }
}

#Preview {
    WelcomePageView(isPresented: .constant(true))
}
