import SwiftUI

/// Router view for the onboarding flow
/// Handles journey states before the user creates their financial plan
struct OnboardingFlowView: View {
    @ObservedObject var viewModel: FinancialViewModel
    @State private var showProfileSheet = false

    // Drill-down sheet states for AnalysisCompleteView
    @State private var showIncomeSheet = false
    @State private var showExpensesSheet = false
    @State private var showDebtMinimumsSheet = false
    @State private var showEmergencyFundSheet = false
    @State private var showDebtSheet = false
    @State private var showInvestmentsSheet = false

    var body: some View {
        ZStack {
            NavigationStack {
                ScrollView {
                    VStack(spacing: DesignTokens.Spacing.lg) {
                        switch viewModel.userJourneyState {
                        case .noAccountsConnected:
                            WelcomeConnectView(viewModel: viewModel)

                        case .accountsConnected:
                            AccountsConnectedView(viewModel: viewModel)

                        case .analysisComplete:
                            analysisCompleteView

                        case .allocationPlanning:
                            AllocationPlannerView(viewModel: viewModel)

                        case .planCreated:
                            // Should not reach here - ContentView switches to TabView
                            EmptyView()
                        }
                    }
                    .padding(DesignTokens.Spacing.md)
                }
                .id(viewModel.userJourneyState)
                .primaryBackgroundGradient()
                .navigationTitle(navigationTitle)
                .toolbar {
                    // Add account button (except during allocation planning)
                    if viewModel.userJourneyState != .noAccountsConnected && viewModel.userJourneyState != .allocationPlanning {
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
                    if viewModel.userJourneyState != .noAccountsConnected {
                        await viewModel.refreshAllData()
                    }
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
                // Drill-down sheets for AnalysisCompleteView
                .sheet(isPresented: $showIncomeSheet) {
                    if let snapshot = viewModel.analysisSnapshot {
                        IncomeDetailSheet(
                            transactions: viewModel.transactions,
                            monthlyAverage: snapshot.monthlyFlow.income
                        )
                    }
                }
                .sheet(isPresented: $showExpensesSheet) {
                    if let snapshot = viewModel.analysisSnapshot {
                        ExpenseDetailSheet(
                            transactions: viewModel.transactions,
                            monthlyAverage: snapshot.monthlyFlow.essentialExpenses,
                            expenseBreakdown: snapshot.monthlyFlow.expenseBreakdown,
                            onValidateTransaction: { _ in }
                        )
                    }
                }
                .sheet(isPresented: $showDebtMinimumsSheet) {
                    if let snapshot = viewModel.analysisSnapshot {
                        DebtMinimumsDetailSheet(
                            accounts: viewModel.accounts,
                            monthlyMinimums: snapshot.monthlyFlow.debtMinimums
                        )
                    }
                }
                .sheet(isPresented: $showEmergencyFundSheet) {
                    if let snapshot = viewModel.analysisSnapshot {
                        EmergencyFundDetailSheet(
                            accounts: viewModel.accounts,
                            totalCash: snapshot.position.emergencyCash,
                            monthsCovered: snapshot.position.emergencyCash / max(snapshot.monthlyFlow.essentialExpenses, 1)
                        )
                    }
                }
                .sheet(isPresented: $showDebtSheet) {
                    if let snapshot = viewModel.analysisSnapshot {
                        DebtMinimumsDetailSheet(
                            accounts: viewModel.accounts,
                            monthlyMinimums: snapshot.monthlyFlow.debtMinimums
                        )
                    }
                }
                .sheet(isPresented: $showInvestmentsSheet) {
                    if let snapshot = viewModel.analysisSnapshot {
                        InvestmentDetailSheet(
                            accounts: viewModel.accounts,
                            totalInvested: snapshot.position.investmentBalances,
                            monthlyContributions: snapshot.position.monthlyInvestmentContributions
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
    }

    // MARK: - Navigation Title

    private var navigationTitle: String {
        switch viewModel.userJourneyState {
        case .noAccountsConnected:
            return "Welcome"
        case .accountsConnected:
            return "Accounts Connected"
        case .analysisComplete:
            return "" // AnalysisCompleteView has its own header
        case .allocationPlanning:
            return "Plan Your Budget"
        case .planCreated:
            return ""
        }
    }

    // MARK: - Analysis Complete View

    @ViewBuilder
    private var analysisCompleteView: some View {
        if let snapshot = viewModel.analysisSnapshot {
            AnalysisCompleteView(
                snapshot: snapshot,
                onSeePlan: {
                    Task {
                        await viewModel.createMyPlan()
                    }
                },
                onDrillDown: { drillDownType in
                    handleDrillDown(drillDownType)
                }
            )
        } else {
            VStack(spacing: DesignTokens.Spacing.xl) {
                ProgressView()
                    .tint(DesignTokens.Colors.accentPrimary)
                Text("Loading analysis...")
                    .subheadlineStyle()
            }
        }
    }

    // MARK: - Drill-Down Handler

    private func handleDrillDown(_ type: AnalysisCompleteView.DrillDownType) {
        switch type {
        case .income:
            showIncomeSheet = true
        case .expenses:
            showExpensesSheet = true
        case .debtMinimums:
            showDebtMinimumsSheet = true
        case .emergencyFund:
            showEmergencyFundSheet = true
        case .debt:
            showDebtSheet = true
        case .investments:
            showInvestmentsSheet = true
        }
    }
}

#if DEBUG
struct OnboardingFlowView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingFlowView(viewModel: FinancialViewModel())
    }
}
#endif
