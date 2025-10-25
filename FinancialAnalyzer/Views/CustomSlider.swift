import SwiftUI

/// Custom slider with color-coded safety zones and haptic feedback
struct CustomSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let recommendedValue: Double
    let warningThreshold: Double
    let hardLimit: Double
    let color: Color
    let onEditingChanged: (Bool) -> Void

    @State private var isDragging: Bool = false
    @State private var currentZone: SafetyZone = .safe
    @GestureState private var dragOffset: CGFloat = 0

    init(
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        step: Double = 50,
        recommendedValue: Double,
        warningThreshold: Double,
        hardLimit: Double,
        color: Color = .blue,
        onEditingChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self._value = value
        self.range = range
        self.step = step
        self.recommendedValue = recommendedValue
        self.warningThreshold = warningThreshold
        self.hardLimit = hardLimit
        self.color = color
        self.onEditingChanged = onEditingChanged
    }

    enum SafetyZone {
        case safe       // 0 → recommended
        case caution    // recommended → warning
        case risky      // warning → hard limit
        case blocked    // beyond hard limit

        var color: Color {
            switch self {
            case .safe: return .green
            case .caution: return .yellow
            case .risky: return .orange
            case .blocked: return .red
            }
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track with color zones
                HStack(spacing: 0) {
                    // Green zone (0 → recommended)
                    Rectangle()
                        .fill(SafetyZone.safe.color.opacity(0.2))
                        .frame(width: zoneWidth(for: .safe, in: geometry))

                    // Yellow zone (recommended → warning)
                    Rectangle()
                        .fill(SafetyZone.caution.color.opacity(0.2))
                        .frame(width: zoneWidth(for: .caution, in: geometry))

                    // Orange zone (warning → limit)
                    Rectangle()
                        .fill(SafetyZone.risky.color.opacity(0.2))
                        .frame(width: zoneWidth(for: .risky, in: geometry))

                    // Red zone (beyond limit - disabled)
                    Rectangle()
                        .fill(SafetyZone.blocked.color.opacity(0.2))
                        .frame(width: zoneWidth(for: .blocked, in: geometry))
                }
                .frame(height: 8)
                .cornerRadius(4)

                // Filled track up to current value
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.6), color],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: thumbOffset(in: geometry), height: 8)
                    .cornerRadius(4)

                // Recommended value marker
                Circle()
                    .fill(Color.green)
                    .frame(width: 4, height: 4)
                    .offset(x: recommendedValueOffset(in: geometry) - 2)

                // Warning threshold marker
                Circle()
                    .fill(Color.orange)
                    .frame(width: 4, height: 4)
                    .offset(x: warningThresholdOffset(in: geometry) - 2)

                // Thumb
                Circle()
                    .fill(color)
                    .frame(width: 28, height: 28)
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
                    .offset(x: thumbOffset(in: geometry) - 14)
                    .scaleEffect(isDragging ? 1.1 : 1.0)
                    .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isDragging)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .updating($dragOffset) { value, state, _ in
                                state = value.translation.width
                            }
                            .onChanged { gesture in
                                if !isDragging {
                                    isDragging = true
                                    onEditingChanged(true)
                                }

                                let newOffset = thumbOffset(in: geometry) + gesture.translation.width
                                let percentage = newOffset / (geometry.size.width - 28)
                                let rawValue = range.lowerBound + (percentage * (range.upperBound - range.lowerBound))

                                // Clamp to hard limit
                                let clampedValue = min(max(rawValue, range.lowerBound), hardLimit)

                                // Snap to step
                                let steppedValue = round(clampedValue / step) * step

                                // Update value
                                value = steppedValue

                                // Check zone transition for haptic feedback
                                let newZone = calculateZone(for: value)
                                if newZone != currentZone {
                                    triggerHaptic(for: newZone)
                                    currentZone = newZone
                                }
                            }
                            .onEnded { _ in
                                isDragging = false
                                onEditingChanged(false)
                            }
                    )
            }
            .frame(height: 44)
        }
        .frame(height: 44)
        .onAppear {
            currentZone = calculateZone(for: value)
        }
    }

    // MARK: - Helper Methods

    private func thumbOffset(in geometry: GeometryProxy) -> CGFloat {
        let percentage = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        return (geometry.size.width - 28) * CGFloat(percentage) + 14
    }

    private func recommendedValueOffset(in geometry: GeometryProxy) -> CGFloat {
        let percentage = (recommendedValue - range.lowerBound) / (range.upperBound - range.lowerBound)
        return (geometry.size.width - 28) * CGFloat(percentage) + 14
    }

    private func warningThresholdOffset(in geometry: GeometryProxy) -> CGFloat {
        let percentage = (warningThreshold - range.lowerBound) / (range.upperBound - range.lowerBound)
        return (geometry.size.width - 28) * CGFloat(percentage) + 14
    }

    private func zoneWidth(for zone: SafetyZone, in geometry: GeometryProxy) -> CGFloat {
        let totalWidth = geometry.size.width
        let rangeSize = range.upperBound - range.lowerBound

        switch zone {
        case .safe:
            // 0 → recommended
            let zoneRange = recommendedValue - range.lowerBound
            return totalWidth * CGFloat(zoneRange / rangeSize)

        case .caution:
            // recommended → warning
            let zoneRange = warningThreshold - recommendedValue
            return totalWidth * CGFloat(zoneRange / rangeSize)

        case .risky:
            // warning → hard limit
            let zoneRange = hardLimit - warningThreshold
            return totalWidth * CGFloat(zoneRange / rangeSize)

        case .blocked:
            // hard limit → range end
            let zoneRange = range.upperBound - hardLimit
            return totalWidth * CGFloat(zoneRange / rangeSize)
        }
    }

    private func calculateZone(for value: Double) -> SafetyZone {
        if value >= hardLimit {
            return .blocked
        } else if value >= warningThreshold {
            return .risky
        } else if value >= recommendedValue {
            return .caution
        } else {
            return .safe
        }
    }

    private func triggerHaptic(for zone: SafetyZone) {
        switch zone {
        case .safe:
            // No haptic for safe zone
            break
        case .caution:
            // Light tap when entering caution
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        case .risky:
            // Medium tap when entering risky
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        case .blocked:
            // Strong tap when hitting limit
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()
        }
    }
}

// MARK: - Preview

#Preview("Custom Slider") {
    VStack(spacing: 40) {
        VStack(alignment: .leading, spacing: 8) {
            Text("Emergency Fund")
                .font(.headline)

            Text("$500")
                .font(.largeTitle)
                .bold()

            CustomSlider(
                value: .constant(500),
                in: 0...5000,
                step: 50,
                recommendedValue: 500,  // 10% of $5000
                warningThreshold: 250,  // 5% minimum
                hardLimit: 2000,        // 40% max
                color: .red
            )

            HStack {
                Text("$0")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("$5,000")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()

        VStack(alignment: .leading, spacing: 8) {
            Text("Discretionary Spending")
                .font(.headline)

            Text("$800")
                .font(.largeTitle)
                .bold()

            CustomSlider(
                value: .constant(800),
                in: 0...5000,
                step: 50,
                recommendedValue: 1000, // 20%
                warningThreshold: 2000, // 40%
                hardLimit: 2500,        // 50% hard limit
                color: .orange
            )

            HStack {
                Text("$0")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("$5,000")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}
