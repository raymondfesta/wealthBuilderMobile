import SwiftUI

/// My Plan view - shows real-time plan adherence for 4 allocation buckets
/// Replaces DashboardView as the main post-onboarding view
struct MyPlanView: View {
    @ObservedObject var viewModel: FinancialViewModel
    @State private var showProfileSheet = false
    @State private var selectedBucket: AllocationBucket?

    // MARK: - Computed Properties

    private var cycleStart: Date {
        Calendar.current.date(from: Calendar.current.dateComponents(
            [.year, .month], from: Date()
        )) ?? Date()
    }

    private var cycleEnd: Date {
        guard let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: cycleStart),
              let lastDay = Calendar.current.date(byAdding: .day, value: -1, to: nextMonth) else {
            return Date()
        }
        return lastDay
    }

    private var daysElapsed: Int {
        Calendar.current.dateComponents([.day], from: cycleStart, to: Date()).day ?? 0
    }

    private var daysRemaining: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: cycleEnd).day ?? 0
    }

    private var totalDaysInCycle: Int {
        Calendar.current.dateComponents([.day], from: cycleStart, to: cycleEnd).day ?? 30
    }

    private var essentialMonthlySpend: Double {
        viewModel.summary?.monthlyFlow.essentialExpenses ?? 0
    }

    /// Filter to show only 4 buckets (Essential, Discretionary, Emergency, Investments)
    private var displayBuckets: [AllocationBucket] {
        viewModel.budgetManager.allocationBuckets
            .filter { $0.type != .debtPaydown }
            .sorted { bucketOrder($0) < bucketOrder($1) }
    }

    /// Overall plan health
    private var isOverallOnTrack: Bool {
        for bucket in displayBuckets {
            let status = calculateStatus(for: bucket)
            if status == .overBudget || status == .behind {
                return false
            }
        }
        return true
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            NavigationStack {
                ScrollView {
                    VStack(spacing: DesignTokens.Spacing.lg) {
                        // Offline banner
                        if viewModel.isOffline {
                            OfflineBannerView()
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        // Header with cycle info
                        cycleHeaderView

                        // 4 bucket cards
                        VStack(spacing: DesignTokens.Spacing.md) {
                            ForEach(displayBuckets) { bucket in
                                PlanAdherenceCard(
                                    bucket: bucket,
                                    transactions: viewModel.transactions,
                                    accounts: viewModel.accounts,
                                    essentialMonthlySpend: essentialMonthlySpend,
                                    cycleStart: cycleStart
                                )
                                .onTapGesture {
                                    selectedBucket = bucket
                                }
                            }
                        }

                        // Last updated footer
                        if viewModel.summary != nil {
                            lastUpdatedFooter
                        }
                    }
                    .padding(DesignTokens.Spacing.md)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.isOffline)
                }
                .primaryBackgroundGradient()
                .navigationTitle("My Plan")
                .toolbar {
                    // Add account button
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            Task {
                                await viewModel.connectBankAccount(from: nil)
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(DesignTokens.Colors.accentPrimary)
                        }
                    }

                    // Profile button
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showProfileSheet = true
                        } label: {
                            Image(systemName: "person.circle")
                                .foregroundColor(DesignTokens.Colors.accentPrimary)
                        }
                    }
                }
                .refreshable {
                    await viewModel.performSmartRefresh(isUserInitiated: true)
                }
                .alert("Error", isPresented: .constant(viewModel.error != nil)) {
                    Button("OK") {
                        viewModel.error = nil
                    }
                } message: {
                    if let error = viewModel.error {
                        Text(error.localizedDescription)
                    }
                }
                .sheet(isPresented: $showProfileSheet) {
                    ProfileView(authService: AuthService.shared)
                }
                .sheet(item: $selectedBucket) { bucket in
                    NavigationStack {
                        AllocationBucketDetailView(
                            bucket: bucket,
                            budgetManager: viewModel.budgetManager
                        )
                    }
                }
            }

            // Loading overlay
            LoadingOverlay(
                currentStep: viewModel.loadingStep,
                isVisible: viewModel.showLoadingOverlay
            )

            // Success banner
            SuccessBanner(
                message: viewModel.successMessage,
                isVisible: viewModel.showSuccessBanner
            )
        }
        .task {
            // Auto-link accounts on view load
            viewModel.autoLinkAccountsToBuckets()
        }
    }

    // MARK: - Cycle Header View

    private var cycleHeaderView: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            // Cycle progress
            HStack {
                Text("Day \(daysElapsed + 1) of \(totalDaysInCycle)")
                    .subheadlineStyle(color: DesignTokens.Colors.textSecondary)

                Spacer()

                Text("\(daysRemaining) days remaining")
                    .subheadlineStyle(color: DesignTokens.Colors.textSecondary)
            }

            // Overall status badge
            HStack {
                Image(systemName: isOverallOnTrack ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(isOverallOnTrack ? DesignTokens.Colors.progressGreen : DesignTokens.Colors.opportunityOrange)

                Text(isOverallOnTrack ? "On Track" : "Needs Attention")
                    .subheadlineStyle(color: isOverallOnTrack ? DesignTokens.Colors.progressGreen : DesignTokens.Colors.opportunityOrange)
                    .fontWeight(.semibold)

                Spacer()
            }
        }
    }

    // MARK: - Last Updated Footer

    private var lastUpdatedFooter: some View {
        HStack {
            Spacer()
            if let lastUpdated = viewModel.summary?.metadata.lastUpdated {
                Text("Updated \(lastUpdated, style: .relative) ago")
                    .captionStyle()
            }
            Spacer()
        }
        .padding(.bottom, DesignTokens.Spacing.lg)
    }

    // MARK: - Helper Functions

    private func bucketOrder(_ bucket: AllocationBucket) -> Int {
        switch bucket.type {
        case .essentialSpending: return 0
        case .discretionarySpending: return 1
        case .emergencyFund: return 2
        case .investments: return 3
        case .debtPaydown: return 4
        }
    }

    private func calculateStatus(for bucket: AllocationBucket) -> PlanAdherenceStatus {
        switch bucket.type {
        case .essentialSpending, .discretionarySpending:
            let spent = TransactionAnalyzer.spentThisCycle(
                for: bucket.type,
                transactions: viewModel.transactions,
                cycleStart: cycleStart
            )
            let projected = TransactionAnalyzer.projectedCycleSpend(
                for: bucket.type,
                transactions: viewModel.transactions,
                cycleStart: cycleStart,
                cycleEnd: cycleEnd
            )

            guard bucket.allocatedAmount > 0 else { return .noData }

            let projectedPercentage = (projected / bucket.allocatedAmount) * 100

            if projectedPercentage <= 100 {
                return .onTrack
            } else if projectedPercentage <= 120 {
                return .warning
            } else {
                return .overBudget
            }

        case .emergencyFund:
            guard bucket.currentBalanceFromAccounts > 0 else {
                return bucket.linkedAccountIds.isEmpty ? .noData : .behind
            }
            let coverage = bucket.monthsOfCoverage(essentialMonthlySpend: essentialMonthlySpend)
            if coverage >= 6 { return .onTrack }
            if coverage >= 3 { return .warning }
            return .behind

        case .investments:
            return bucket.linkedAccountIds.isEmpty ? .noData : .onTrack

        case .debtPaydown:
            return .noData
        }
    }
}
