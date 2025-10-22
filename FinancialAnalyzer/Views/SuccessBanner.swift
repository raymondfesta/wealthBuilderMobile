import SwiftUI

/// Auto-dismissing success banner that appears after data analysis completes
struct SuccessBanner: View {
    let message: String
    let isVisible: Bool

    var body: some View {
        VStack {
            if isVisible {
                HStack(spacing: 12) {
                    // Success icon
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)

                    // Message
                    Text(message)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.green)
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                )
                .padding(.horizontal, 16)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            Spacer()
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isVisible)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.gray.opacity(0.1)
            .ignoresSafeArea()

        SuccessBanner(
            message: "Reviewed 247 transactions and generated 6 budgets",
            isVisible: true
        )
    }
}
