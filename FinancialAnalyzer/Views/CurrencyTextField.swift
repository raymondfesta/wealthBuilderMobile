import SwiftUI

/// A tappable currency display that opens an editor sheet for precise dollar input
struct CurrencyTextField: View {
    @Binding var value: Double
    let minValue: Double
    let maxValue: Double
    let label: String
    let color: Color
    let onCommit: (Double) -> Void

    @State private var showingEditor = false
    @State private var editingText = ""
    @State private var showingValidationError = false
    @State private var validationMessage = ""

    var body: some View {
        Button {
            showingEditor = true
            editingText = String(format: "%.0f", value)
        } label: {
            HStack(spacing: 8) {
                Text(formatCurrency(value))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(color)

                Image(systemName: "pencil.circle.fill")
                    .font(.title2)
                    .foregroundColor(color.opacity(0.6))
            }
        }
        .sheet(isPresented: $showingEditor) {
            editorSheet
        }
        .alert("Invalid Amount", isPresented: $showingValidationError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(validationMessage)
        }
    }

    private var editorSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Current value display
                VStack(spacing: 8) {
                    Text(label)
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text(formatCurrency(value))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(color)
                }
                .padding(.top, 40)

                // Input section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Enter New Amount")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    HStack {
                        Text("$")
                            .font(.title)
                            .foregroundColor(.secondary)

                        TextField("0", text: $editingText)
                            .font(.system(size: 32, weight: .semibold, design: .rounded))
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.leading)
                            .onChange(of: editingText) { newValue in
                                // Filter to numbers only
                                editingText = newValue.filter { $0.isNumber }
                            }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)

                    // Range guidance
                    HStack {
                        Text("Range: \(formatCurrency(minValue)) – \(formatCurrency(maxValue))")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()
                    }
                }
                .padding(.horizontal)

                Spacer()

                // Preview of new value
                if let previewValue = Double(editingText), previewValue > 0 {
                    VStack(spacing: 8) {
                        Text("New Amount")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(formatCurrency(previewValue))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(isValidAmount(previewValue) ? color : .orange)
                    }
                    .padding()
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Edit Amount")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showingEditor = false
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        commitValue()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canCommit)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Computed Properties

    private var canCommit: Bool {
        guard let newValue = Double(editingText) else { return false }
        return isValidAmount(newValue) && newValue != value
    }

    // MARK: - Helper Methods

    private func isValidAmount(_ amount: Double) -> Bool {
        return amount >= minValue && amount <= maxValue
    }

    private func commitValue() {
        guard let newValue = Double(editingText) else {
            validationMessage = "Please enter a valid number."
            showingValidationError = true
            return
        }

        if newValue < minValue {
            validationMessage = "Amount must be at least \(formatCurrency(minValue))."
            showingValidationError = true
            return
        }

        if newValue > maxValue {
            validationMessage = "Amount cannot exceed \(formatCurrency(maxValue))."
            showingValidationError = true
            return
        }

        // Valid amount - commit and close
        value = newValue
        onCommit(newValue)
        showingEditor = false

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

// MARK: - Preview

#Preview("Currency TextField") {
    VStack(spacing: 40) {
        CurrencyTextField(
            value: .constant(500),
            minValue: 0,
            maxValue: 5000,
            label: "Emergency Fund",
            color: .red,
            onCommit: { newValue in
                print("Committed: $\(newValue)")
            }
        )
        .padding()

        CurrencyTextField(
            value: .constant(800),
            minValue: 0,
            maxValue: 5000,
            label: "Discretionary Spending",
            color: .orange,
            onCommit: { newValue in
                print("Committed: $\(newValue)")
            }
        )
        .padding()
    }
}
