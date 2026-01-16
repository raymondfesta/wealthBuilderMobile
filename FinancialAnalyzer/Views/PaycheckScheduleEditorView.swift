import SwiftUI

/// Settings view for editing paycheck schedule configuration
struct PaycheckScheduleEditorView: View {
    @ObservedObject var viewModel: FinancialViewModel
    let config: AllocationScheduleConfig
    @Environment(\.dismiss) private var dismiss

    @State private var selectedFrequency: PaycheckFrequency
    @State private var estimatedAmount: String
    @State private var anchorDay1: Int
    @State private var anchorDay2: Int
    @State private var anchorWeekday: Int

    @State private var notificationsEnabled: Bool
    @State private var sendPrePayday: Bool
    @State private var sendPayday: Bool
    @State private var sendFollowUp: Bool
    @State private var followUpDelayDays: Int

    @State private var upcomingMonths: Int
    @State private var historyMonths: Int

    @State private var hasChanges: Bool = false
    @State private var isSaving: Bool = false

    init(viewModel: FinancialViewModel, config: AllocationScheduleConfig) {
        self.viewModel = viewModel
        self.config = config

        // Initialize state from config
        _selectedFrequency = State(initialValue: config.paycheckSchedule.frequency)
        _estimatedAmount = State(initialValue: String(format: "%.0f", config.paycheckSchedule.estimatedAmount))

        // Anchor dates
        if let firstAnchor = config.paycheckSchedule.anchorDates.first {
            _anchorWeekday = State(initialValue: firstAnchor.weekday ?? 6)
            _anchorDay1 = State(initialValue: firstAnchor.day ?? 1)
        } else {
            _anchorWeekday = State(initialValue: 6)
            _anchorDay1 = State(initialValue: 1)
        }

        if config.paycheckSchedule.anchorDates.count > 1,
           let day = config.paycheckSchedule.anchorDates[1].day {
            _anchorDay2 = State(initialValue: day)
        } else {
            _anchorDay2 = State(initialValue: 15)
        }

        // Notification preferences
        _notificationsEnabled = State(initialValue: config.notificationsEnabled)
        _sendPrePayday = State(initialValue: config.sendPrePaydayReminder)
        _sendPayday = State(initialValue: config.sendPaydayNotification)
        _sendFollowUp = State(initialValue: config.sendFollowUpReminder)
        _followUpDelayDays = State(initialValue: config.followUpDelayDays)

        // Display preferences
        _upcomingMonths = State(initialValue: config.upcomingMonthsToShow)
        _historyMonths = State(initialValue: config.historyMonthsToKeep)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Paycheck Schedule section
                Section {
                    Picker("Frequency", selection: $selectedFrequency) {
                        ForEach(PaycheckFrequency.allCases, id: \.self) { freq in
                            Text(freq.rawValue).tag(freq)
                        }
                    }
                    .onChange(of: selectedFrequency) { _ in
                        hasChanges = true
                    }

                    HStack {
                        Text("Amount")
                        Spacer()
                        TextField("Amount", text: $estimatedAmount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .onChange(of: estimatedAmount) { _ in
                                hasChanges = true
                            }
                    }

                    anchorDatesSection

                } header: {
                    Text("Paycheck Schedule")
                } footer: {
                    Text("Changes will regenerate your upcoming allocations.")
                }

                // Notifications section
                Section {
                    Toggle("Enable Notifications", isOn: $notificationsEnabled)
                        .onChange(of: notificationsEnabled) { _ in
                            hasChanges = true
                        }

                    if notificationsEnabled {
                        Toggle("Pre-Payday Reminder", isOn: $sendPrePayday)
                            .onChange(of: sendPrePayday) { _ in
                                hasChanges = true
                            }

                        Toggle("Payday Notification", isOn: $sendPayday)
                            .onChange(of: sendPayday) { _ in
                                hasChanges = true
                            }

                        Toggle("Follow-Up Reminder", isOn: $sendFollowUp)
                            .onChange(of: sendFollowUp) { _ in
                                hasChanges = true
                            }

                        if sendFollowUp {
                            Stepper("Follow-up after \(followUpDelayDays) day\(followUpDelayDays == 1 ? "" : "s")",
                                    value: $followUpDelayDays, in: 1...7)
                            .onChange(of: followUpDelayDays) { _ in
                                hasChanges = true
                            }
                        }
                    }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Get reminders when it's time to allocate your paycheck.")
                }

                // Display preferences section
                Section {
                    Stepper("Show \(upcomingMonths) month\(upcomingMonths == 1 ? "" : "s") ahead",
                            value: $upcomingMonths, in: 1...6)
                    .onChange(of: upcomingMonths) { _ in
                        hasChanges = true
                    }

                    Stepper("Keep \(historyMonths) month\(historyMonths == 1 ? "" : "s") of history",
                            value: $historyMonths, in: 3...24)
                    .onChange(of: historyMonths) { _ in
                        hasChanges = true
                    }
                } header: {
                    Text("Display")
                }
            }
            .navigationTitle("Schedule Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(!hasChanges || !isValid)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Anchor Dates Section

    @ViewBuilder
    private var anchorDatesSection: some View {
        switch selectedFrequency {
        case .weekly, .biweekly:
            Picker("Payday", selection: $anchorWeekday) {
                Text("Sunday").tag(1)
                Text("Monday").tag(2)
                Text("Tuesday").tag(3)
                Text("Wednesday").tag(4)
                Text("Thursday").tag(5)
                Text("Friday").tag(6)
                Text("Saturday").tag(7)
            }
            .onChange(of: anchorWeekday) { _ in
                hasChanges = true
            }

        case .semimonthly:
            Picker("First Payday", selection: $anchorDay1) {
                ForEach(1...28, id: \.self) { day in
                    Text("\(day)").tag(day)
                }
            }
            .onChange(of: anchorDay1) { _ in
                hasChanges = true
            }

            Picker("Second Payday", selection: $anchorDay2) {
                ForEach(1...28, id: \.self) { day in
                    Text("\(day)").tag(day)
                }
            }
            .onChange(of: anchorDay2) { _ in
                hasChanges = true
            }

        case .monthly:
            Picker("Payday (Day of Month)", selection: $anchorDay1) {
                ForEach(1...28, id: \.self) { day in
                    Text("\(day)").tag(day)
                }
            }
            .onChange(of: anchorDay1) { _ in
                hasChanges = true
            }
        }
    }

    // MARK: - Computed Properties

    private var isValid: Bool {
        guard let amount = Double(estimatedAmount), amount > 0 else {
            return false
        }
        return true
    }

    // MARK: - Methods

    private func saveChanges() {
        guard let amount = Double(estimatedAmount), amount > 0 else {
            return
        }

        isSaving = true

        // Build anchor dates based on frequency
        let anchorDates: [DateComponents]
        switch selectedFrequency {
        case .weekly, .biweekly:
            anchorDates = [DateComponents(weekday: anchorWeekday)]
        case .semimonthly:
            anchorDates = [DateComponents(day: anchorDay1), DateComponents(day: anchorDay2)]
        case .monthly:
            anchorDates = [DateComponents(day: anchorDay1)]
        }

        // Update paycheck schedule
        var updatedSchedule = config.paycheckSchedule
        updatedSchedule.update(frequency: selectedFrequency, amount: amount, anchorDates: anchorDates)

        // Update config
        var updatedConfig = config
        updatedConfig.updatePaycheckSchedule(updatedSchedule)
        updatedConfig.updateNotificationPreferences(
            enabled: notificationsEnabled,
            prePayday: sendPrePayday,
            payday: sendPayday,
            followUp: sendFollowUp,
            followUpDelay: followUpDelayDays
        )
        updatedConfig.updateDisplayPreferences(
            upcomingMonths: upcomingMonths,
            historyMonths: historyMonths
        )

        Task {
            await viewModel.updateAllocationSchedule(config: updatedConfig)

            await MainActor.run {
                isSaving = false
                dismiss()
            }
        }
    }
}

// MARK: - Preview

#Preview("Schedule Editor") {
    let viewModel = FinancialViewModel()

    let schedule = PaycheckSchedule(
        frequency: .biweekly,
        estimatedAmount: 2500,
        confidence: .high,
        isUserConfirmed: true,
        anchorDates: [DateComponents(weekday: 6)]
    )
    let config = AllocationScheduleConfig(paycheckSchedule: schedule)

    return PaycheckScheduleEditorView(viewModel: viewModel, config: config)
}
