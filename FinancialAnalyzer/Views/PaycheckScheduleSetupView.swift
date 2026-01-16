import SwiftUI

/// Onboarding flow for setting up paycheck schedule after allocation plan creation
struct PaycheckScheduleSetupView: View {
    @ObservedObject var viewModel: FinancialViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var detectedSchedule: PaycheckSchedule?
    @State private var confidence: PaycheckDetectionConfidence = .low
    @State private var detectionMessage: String = ""
    @State private var isDetecting: Bool = true

    // Editable schedule fields
    @State private var selectedFrequency: PaycheckFrequency = .monthly
    @State private var estimatedAmount: String = ""
    @State private var anchorDay1: Int = 1
    @State private var anchorDay2: Int = 15
    @State private var anchorWeekday: Int = 6  // Friday

    // Notification permission
    @State private var showingNotificationPrompt: Bool = false
    @State private var notificationPermissionGranted: Bool = false

    // Preview
    @State private var previewDates: [Date] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    if isDetecting {
                        detectingSection
                    } else {
                        // Detection result
                        detectionResultSection

                        // Schedule editor
                        scheduleEditorSection

                        // Preview
                        previewSection

                        // Notification prompt
                        if showingNotificationPrompt {
                            notificationPromptSection
                        }

                        // Create button
                        createScheduleButton
                    }
                }
                .padding()
            }
            .navigationTitle("Set Up Your Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                detectPaycheckSchedule()
            }
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 48))
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)

            Text("When Do You Get Paid?")
                .font(.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity)

            Text("We'll schedule your allocations to match your paycheck, so you never miss a payday.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical)
    }

    private var detectingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Analyzing your transaction history...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var detectionResultSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: confidence.icon)
                    .font(.title2)
                    .foregroundColor(Color(hex: confidence.color))

                VStack(alignment: .leading, spacing: 4) {
                    Text(confidence == .manual ? "Manual Setup" : "Pattern Detected")
                        .font(.headline)

                    Text(detectionMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }

    private var scheduleEditorSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Schedule Details")
                .font(.headline)

            // Frequency picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Pay Frequency")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Picker("Frequency", selection: $selectedFrequency) {
                    ForEach(PaycheckFrequency.allCases, id: \.self) { freq in
                        Text(freq.rawValue).tag(freq)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedFrequency) { _ in
                    updatePreview()
                }
            }

            // Amount field
            VStack(alignment: .leading, spacing: 8) {
                Text("Estimated Paycheck Amount")
                    .font(.subheadline)
                    .fontWeight(.medium)

                TextField("Amount", text: $estimatedAmount)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .font(.title3)
                    .onChange(of: estimatedAmount) { _ in
                        updatePreview()
                    }
            }

            // Anchor dates (varies by frequency)
            anchorDatesSection
        }
    }

    @ViewBuilder
    private var anchorDatesSection: some View {
        switch selectedFrequency {
        case .weekly, .biweekly:
            VStack(alignment: .leading, spacing: 8) {
                Text("Payday")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Picker("Weekday", selection: $anchorWeekday) {
                    Text("Sunday").tag(1)
                    Text("Monday").tag(2)
                    Text("Tuesday").tag(3)
                    Text("Wednesday").tag(4)
                    Text("Thursday").tag(5)
                    Text("Friday").tag(6)
                    Text("Saturday").tag(7)
                }
                .pickerStyle(.menu)
                .onChange(of: anchorWeekday) { _ in
                    updatePreview()
                }
            }

        case .semimonthly:
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("First Payday")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Picker("Day", selection: $anchorDay1) {
                        ForEach(1...28, id: \.self) { day in
                            Text("\(day)").tag(day)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: anchorDay1) { _ in
                        updatePreview()
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Second Payday")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Picker("Day", selection: $anchorDay2) {
                        ForEach(1...28, id: \.self) { day in
                            Text("\(day)").tag(day)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: anchorDay2) { _ in
                        updatePreview()
                    }
                }
            }

        case .monthly:
            VStack(alignment: .leading, spacing: 8) {
                Text("Payday (Day of Month)")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Picker("Day", selection: $anchorDay1) {
                    ForEach(1...28, id: \.self) { day in
                        Text("\(day)").tag(day)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: anchorDay1) { _ in
                    updatePreview()
                }
            }
        }
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Next 3 Paychecks")
                .font(.headline)

            if previewDates.isEmpty {
                Text("Enter amount to see preview")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                VStack(spacing: 8) {
                    ForEach(previewDates.prefix(3), id: \.self) { date in
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.blue)

                            Text(formatDate(date))
                                .font(.subheadline)

                            Spacer()

                            if let amount = Double(estimatedAmount) {
                                Text(formatCurrency(amount))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(8)
                    }
                }
            }
        }
    }

    private var notificationPromptSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "bell.badge.fill")
                    .font(.title2)
                    .foregroundColor(.orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Enable Reminders?")
                        .font(.headline)

                    Text("We'll remind you when it's time to allocate your paycheck")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Button {
                requestNotificationPermission()
            } label: {
                Text("Enable Notifications")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }

            Button {
                showingNotificationPrompt = false
            } label: {
                Text("Maybe Later")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }

    private var createScheduleButton: some View {
        Button {
            createSchedule()
        } label: {
            HStack {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Create Schedule")
                }
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(isValid ? Color.blue : Color.gray)
            .cornerRadius(16)
            .shadow(color: isValid ? Color.blue.opacity(0.3) : Color.clear, radius: 8, x: 0, y: 4)
        }
        .disabled(!isValid || viewModel.isLoading)
    }

    // MARK: - Computed Properties

    private var isValid: Bool {
        guard let amount = Double(estimatedAmount), amount > 0 else {
            return false
        }
        return true
    }

    // MARK: - Methods

    private func detectPaycheckSchedule() {
        Task {
            // Simulate detection delay
            try? await Task.sleep(nanoseconds: 1_500_000_000)  // 1.5 seconds

            let detectionService = PaycheckDetectionService()
            let result = detectionService.detectPaycheckSchedule(from: viewModel.transactions)

            await MainActor.run {
                isDetecting = false

                if let schedule = result.schedule {
                    // Detected successfully
                    detectedSchedule = schedule
                    confidence = schedule.confidence
                    detectionMessage = result.message
                    selectedFrequency = schedule.frequency
                    estimatedAmount = String(format: "%.0f", schedule.estimatedAmount)

                    // Set anchor dates
                    if let firstAnchor = schedule.anchorDates.first {
                        if let weekday = firstAnchor.weekday {
                            anchorWeekday = weekday
                        }
                        if let day = firstAnchor.day {
                            anchorDay1 = day
                        }
                    }
                    if schedule.anchorDates.count > 1, let day = schedule.anchorDates[1].day {
                        anchorDay2 = day
                    }
                } else {
                    // Detection failed - use manual setup
                    confidence = .manual
                    detectionMessage = result.message
                    selectedFrequency = .monthly
                    estimatedAmount = viewModel.summary?.avgMonthlyIncome.description ?? ""
                }

                updatePreview()

                // Show notification prompt after brief delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    showingNotificationPrompt = true
                }
            }
        }
    }

    private func updatePreview() {
        guard let amount = Double(estimatedAmount), amount > 0 else {
            previewDates = []
            return
        }

        let anchorDates: [DateComponents]
        switch selectedFrequency {
        case .weekly, .biweekly:
            anchorDates = [DateComponents(weekday: anchorWeekday)]
        case .semimonthly:
            anchorDates = [DateComponents(day: anchorDay1), DateComponents(day: anchorDay2)]
        case .monthly:
            anchorDates = [DateComponents(day: anchorDay1)]
        }

        let tempSchedule = PaycheckSchedule(
            frequency: selectedFrequency,
            estimatedAmount: amount,
            confidence: confidence,
            isUserConfirmed: false,
            anchorDates: anchorDates
        )

        previewDates = tempSchedule.nextPaycheckDates(from: Date(), count: 3)
    }

    private func requestNotificationPermission() {
        Task {
            do {
                let granted = try await NotificationService.shared.requestAuthorization()
                await MainActor.run {
                    notificationPermissionGranted = granted
                    showingNotificationPrompt = false
                }
            } catch {
                print("❌ [PaycheckSetup] Failed to request notification permission: \(error)")
            }
        }
    }

    private func createSchedule() {
        guard let amount = Double(estimatedAmount), amount > 0 else {
            return
        }

        let anchorDates: [DateComponents]
        switch selectedFrequency {
        case .weekly, .biweekly:
            anchorDates = [DateComponents(weekday: anchorWeekday)]
        case .semimonthly:
            anchorDates = [DateComponents(day: anchorDay1), DateComponents(day: anchorDay2)]
        case .monthly:
            anchorDates = [DateComponents(day: anchorDay1)]
        }

        let paycheckSchedule = PaycheckSchedule(
            frequency: selectedFrequency,
            estimatedAmount: amount,
            confidence: confidence,
            isUserConfirmed: true,
            anchorDates: anchorDates,
            sourceTransactionIds: detectedSchedule?.sourceTransactionIds ?? []
        )

        Task {
            await viewModel.setupAllocationSchedule(paycheckSchedule: paycheckSchedule)
            await MainActor.run {
                dismiss()
            }
        }
    }

    // MARK: - Formatters

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d, yyyy"
        return formatter.string(from: date)
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

// MARK: - Preview

#Preview("Paycheck Setup") {
    let viewModel = FinancialViewModel()
    return PaycheckScheduleSetupView(viewModel: viewModel)
}
