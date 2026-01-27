import SwiftUI

/// Main container for the Schedule tab with Upcoming/History segmented control
struct ScheduleTabView: View {
    @ObservedObject var viewModel: FinancialViewModel
    @State private var selectedSegment: ScheduleSegment = .upcoming
    @State private var showingScheduleEditor: Bool = false
    @State private var showingSetup: Bool = false

    enum ScheduleSegment: String, CaseIterable {
        case upcoming = "Upcoming"
        case history = "History"
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.allocationScheduleConfig == nil {
                    // No schedule configured - show setup prompt
                    setupPromptView
                } else {
                    // Schedule configured - show main content
                    mainContentView
                }
            }
            .navigationTitle("Schedule")
            .toolbar {
                if viewModel.allocationScheduleConfig != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showingScheduleEditor = true
                        } label: {
                            Image(systemName: "gear")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingSetup) {
                PaycheckScheduleSetupView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingScheduleEditor) {
                if let config = viewModel.allocationScheduleConfig {
                    PaycheckScheduleEditorView(viewModel: viewModel, config: config)
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    // MARK: - Setup Prompt View

    private var setupPromptView: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            Spacer()

            // Icon
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 80))
                .foregroundColor(DesignTokens.Colors.accentSecondary.opacity(0.6))

            VStack(spacing: DesignTokens.Spacing.sm) {
                Text("No Schedule Yet")
                    .title3Style()

                Text("Set up your paycheck schedule to see when your allocations are due.")
                    .subheadlineStyle()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignTokens.Spacing.xxl)
            }

            PrimaryButton(title: "Set Up Schedule") {
                showingSetup = true
            }
            .padding(.horizontal, DesignTokens.Spacing.xxl)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .primaryBackgroundGradient()
    }

    // MARK: - Main Content View

    private var mainContentView: some View {
        VStack(spacing: 0) {
            // Segmented control
            Picker("View", selection: $selectedSegment) {
                ForEach(ScheduleSegment.allCases, id: \.self) { segment in
                    Text(segment.rawValue).tag(segment)
                }
            }
            .pickerStyle(.segmented)
            .padding(DesignTokens.Spacing.md)

            // Content based on selection
            switch selectedSegment {
            case .upcoming:
                UpcomingAllocationsView(viewModel: viewModel)
            case .history:
                AllocationHistoryView(viewModel: viewModel)
            }
        }
        .primaryBackgroundGradient()
    }
}

// MARK: - Preview

#Preview("Schedule Tab - No Setup") {
    let viewModel = FinancialViewModel()
    return ScheduleTabView(viewModel: viewModel)
}

#Preview("Schedule Tab - With Schedule") {
    let viewModel: FinancialViewModel = {
        let vm = FinancialViewModel()

        // Mock schedule config
        let schedule = PaycheckSchedule(
            frequency: .biweekly,
            estimatedAmount: 2500,
            confidence: .high,
            isUserConfirmed: true,
            anchorDates: [DateComponents(weekday: 6)]
        )
        vm.allocationScheduleConfig = AllocationScheduleConfig(paycheckSchedule: schedule)

        // Mock scheduled allocations
        let today = Date()
        vm.scheduledAllocations = [
            ScheduledAllocation(
                paycheckDate: today,
                bucketType: .essentialSpending,
                scheduledAmount: 1250,
                status: .upcoming
            ),
            ScheduledAllocation(
                paycheckDate: today,
                bucketType: .emergencyFund,
                scheduledAmount: 500,
                status: .upcoming
            ),
            ScheduledAllocation(
                paycheckDate: today,
                bucketType: .discretionarySpending,
                scheduledAmount: 500,
                status: .upcoming
            ),
            ScheduledAllocation(
                paycheckDate: today,
                bucketType: .investments,
                scheduledAmount: 250,
                status: .upcoming
            )
        ]

        return vm
    }()

    return ScheduleTabView(viewModel: viewModel)
}
