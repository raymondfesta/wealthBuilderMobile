import SwiftUI

/// Shows analysis results after account connection
/// Mimics financial advisor discovery presentation: facts first, recommendations later
struct AnalysisCompleteView: View {
    let snapshot: AnalysisSnapshot
    @ObservedObject var viewModel: FinancialViewModel
    let onSeePlan: () -> Void
    let onAddAccount: () -> Void

    // MARK: - Drill-Down Sheet State

    @State private var showIncomeSheet = false
    @State private var showExpensesSheet = false
    @State private var showDebtMinimumsSheet = false
    @State private var showEmergencyFundSheet = false
    @State private var showDebtSheet = false
    @State private var showInvestmentsSheet = false

    // MARK: - Computed Properties

    /// Whether user has connected any debt accounts
    private var hasDebtAccounts: Bool {
        viewModel.accounts.contains { $0.isCredit || $0.isLoan }
    }

    /// Whether user has connected any investment accounts
    private var hasInvestmentAccounts: Bool {
        viewModel.accounts.contains { $0.isInvestment }
    }

    /// Whether to show the transaction review section
    private var shouldShowReviewSection: Bool {
        !viewModel.transactionsNeedingTransferReview.isEmpty
    }

    /// Disposable income (available to allocate)
    private var disposableIncome: Double {
        snapshot.disposableIncome
    }

    /// Whether disposable income is negative
    private var hasNegativeDisposable: Bool {
        disposableIncome < 0
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                // Header
                headerSection

                // Transaction Review Section (conditional - show first for visibility)
                if shouldShowReviewSection {
                    TransactionReviewSection(viewModel: viewModel)
                }

                // Card 1: Financial Position (FIRST per mockup)
                financialPositionCard

                // Card 2: Monthly Money Flow (SECOND per mockup)
                monthlyFlowCard

                // Disposable Income Card with soft warning for negative
                DisposableIncomeCard(
                    disposableIncome: disposableIncome,
                    monthlyIncome: snapshot.monthlyFlow.income,
                    monthlyExpenses: snapshot.monthlyFlow.essentialExpenses,
                    hasFlaggedTransactions: shouldShowReviewSection,
                    onReviewTransactions: {
                        // Scroll to review section (or highlight it)
                    },
                    onProceedAnyway: onSeePlan
                )

                // Validation indicator if needed (legacy - for low confidence transactions)
                if snapshot.metadata.transactionsNeedingValidation > 0 && !shouldShowReviewSection {
                    validationIndicator
                }

                Spacer(minLength: 100)
            }
            .padding(.top, DesignTokens.Spacing.md)
            .padding(.horizontal, DesignTokens.Spacing.md)
        }
        .safeAreaInset(edge: .bottom) {
            // Only show CTA if disposable is positive or no flagged transactions
            if !hasNegativeDisposable || !shouldShowReviewSection {
                PrimaryButton(title: "Create my allocation plan", action: onSeePlan)
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.bottom, DesignTokens.Spacing.xs)
                    .background(
                        DesignTokens.Colors.backgroundPrimary
                            .opacity(0.95)
                            .blur(radius: 10)
                    )
            }
        }
        .sheet(isPresented: $showIncomeSheet) {
            IncomeBreakdownSheet(
                transactions: viewModel.transactions,
                monthlyAverage: snapshot.monthlyFlow.income
            )
        }
        .sheet(isPresented: $showExpensesSheet) {
            if let breakdown = snapshot.monthlyFlow.expenseBreakdown {
                ExpenseBreakdownSheet(
                    breakdown: breakdown,
                    monthlyAverage: snapshot.monthlyFlow.essentialExpenses,
                    transactions: viewModel.transactions
                )
            }
        }
        .sheet(isPresented: $showDebtMinimumsSheet) {
            DebtMinimumsBreakdownSheet(
                accounts: viewModel.accounts,
                monthlyMinimums: snapshot.monthlyFlow.debtMinimums
            )
        }
        .sheet(isPresented: $showEmergencyFundSheet) {
            EmergencyFundBreakdownSheet(
                accounts: viewModel.accounts,
                totalCash: snapshot.position.emergencyCash,
                monthsCovered: snapshot.position.emergencyCash / max(snapshot.monthlyFlow.essentialExpenses, 1)
            )
        }
        .sheet(isPresented: $showDebtSheet) {
            DebtBreakdownSheet(
                accounts: viewModel.accounts,
                totalDebt: snapshot.position.totalDebt
            )
        }
        .sheet(isPresented: $showInvestmentsSheet) {
            InvestmentBreakdownSheet(
                accounts: viewModel.accounts,
                totalInvested: snapshot.position.investmentBalances,
                monthlyContributions: snapshot.position.monthlyInvestmentContributions
            )
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text("Analysis complete")
                .displayStyle()

            Text("Analyzed \(snapshot.metadata.transactionsAnalyzed) transactions over \(snapshot.metadata.monthsAnalyzed) months.")
                .subheadlineStyle()
        }
    }

    // MARK: - Financial Position Card

    private var financialPositionCard: some View {
        GlassmorphicCard(
            title: "Your Financial Position",
            subtitle: "A real-time snapshot of where your money stands today."
        ) {
            VStack(spacing: 0) {
                // Emergency Fund row
                FinancialMetricRow(
                    label: "Emergency Fund",
                    value: snapshot.position.emergencyCash
                ) {
                    showEmergencyFundSheet = true
                }

                cardDivider

                // Total Debt row
                FinancialMetricRow(
                    label: "Total Debt:",
                    value: snapshot.position.totalDebt
                ) {
                    showDebtSheet = true
                }

                cardDivider

                // Investments row
                FinancialMetricRow(
                    label: "Investments:",
                    value: snapshot.position.investmentBalances,
                    showChevron: true
                ) {
                    showInvestmentsSheet = true
                }
            }
        }
    }

    // MARK: - Monthly Flow Card

    private var monthlyFlowCard: some View {
        GlassmorphicCard(
            title: "Your monthly money flow",
            subtitle: "A clear picture of your monthly inflows and outflows."
        ) {
            VStack(spacing: 0) {
                // Income row
                FinancialMetricRow(
                    label: "Income:",
                    value: snapshot.monthlyFlow.income,
                    valueColor: DesignTokens.Colors.progressGreen
                ) {
                    showIncomeSheet = true
                }

                cardDivider

                // Essential Expenses row
                FinancialMetricRow(
                    label: "Essential Expenses:",
                    value: -snapshot.monthlyFlow.essentialExpenses
                ) {
                    showExpensesSheet = true
                }

                cardDivider

                // Debt Minimums row
                FinancialMetricRow(
                    label: "Debt Minimums:",
                    value: -snapshot.monthlyFlow.debtMinimums
                ) {
                    showDebtMinimumsSheet = true
                }

                // To Allocate row (highlighted)
                HStack {
                    Text("To Allocate:")
                        .headlineStyle(color: DesignTokens.Colors.accentPrimary)

                    Spacer()

                    Text(formatCurrency(snapshot.monthlyFlow.discretionaryIncome))
                        .title3Style(color: DesignTokens.Colors.accentPrimary)
                }
                .padding(.top, DesignTokens.Spacing.md)
            }
        }
    }

    // MARK: - Validation Indicator

    private var validationIndicator: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: "exclamationmark.circle")
                .foregroundColor(DesignTokens.Colors.opportunityOrange)

            Text("\(snapshot.metadata.transactionsNeedingValidation) transactions need review")
                .subheadlineStyle()
        }
        .padding(DesignTokens.Spacing.md)
        .frame(maxWidth: .infinity)
        .primaryCardStyle()
    }

    // MARK: - Helpers

    private var cardDivider: some View {
        Rectangle()
            .fill(DesignTokens.Colors.divider)
            .frame(height: 1)
            .padding(.vertical, DesignTokens.Spacing.sm)
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
}

// MARK: - Preview

#if DEBUG
struct AnalysisCompleteView_Previews: PreviewProvider {
    static var richViewModel: FinancialViewModel {
        let vm = FinancialViewModel()

        // Depository accounts
        vm.accounts = [
            BankAccount(
                id: "chk-1", itemId: "item-1", name: "Primary Checking",
                type: "depository", subtype: "checking", mask: "4521",
                currentBalance: 3200, availableBalance: 3100
            ),
            BankAccount(
                id: "sav-1", itemId: "item-1", name: "Emergency Savings",
                type: "depository", subtype: "savings", mask: "7890",
                currentBalance: 22800, availableBalance: 22800
            ),
            // Credit card
            BankAccount(
                id: "cc-1", itemId: "item-1", name: "Chase Sapphire",
                type: "credit", subtype: "credit card", mask: "3344",
                currentBalance: 1850, limit: 10000, apr: 0.2199
            ),
            // Investment
            BankAccount(
                id: "inv-1", itemId: "item-2", name: "Vanguard Brokerage",
                type: "investment", subtype: "brokerage", mask: "5566",
                currentBalance: 81250
            ),
            // Loan
            BankAccount(
                id: "loan-1", itemId: "item-1", name: "Auto Loan",
                type: "loan", subtype: "auto", mask: "9012",
                currentBalance: 14500, minimumPayment: 350, apr: 0.069
            ),
        ]

        // Transactions with some needing transfer review
        vm.transactions = [
            Transaction(
                id: "t-1", accountId: "chk-1", amount: 500,
                date: Date(), name: "Transfer to Ally Bank",
                merchantName: "Ally",
                category: ["Transfer"], categoryId: "21001000",
                personalFinanceCategory: PersonalFinanceCategory(
                    primary: "TRANSFER_OUT", detailed: "TRANSFER_OUT_ACCOUNT_TRANSFER",
                    confidenceLevel: .high
                )
            ),
            Transaction(
                id: "t-2", accountId: "chk-1", amount: 1000,
                date: Date(), name: "USAA Transfer",
                merchantName: "USAA",
                category: ["Transfer"], categoryId: "21001000",
                personalFinanceCategory: PersonalFinanceCategory(
                    primary: "TRANSFER_OUT", detailed: "TRANSFER_OUT_ACCOUNT_TRANSFER",
                    confidenceLevel: .medium
                )
            ),
            Transaction(
                id: "t-3", accountId: "chk-1", amount: 1200,
                date: Date(), name: "Rent Payment",
                merchantName: "Landlord LLC",
                category: ["Rent"], categoryId: "12001000",
                personalFinanceCategory: PersonalFinanceCategory(
                    primary: "RENT_AND_UTILITIES", detailed: "RENT_AND_UTILITIES_RENT",
                    confidenceLevel: .veryHigh
                )
            ),
            Transaction(
                id: "t-4", accountId: "chk-1", amount: 85.50,
                date: Date(), name: "Whole Foods Market",
                merchantName: "Whole Foods",
                category: ["Food and Drink", "Groceries"],
                personalFinanceCategory: PersonalFinanceCategory(
                    primary: "FOOD_AND_DRINK", detailed: "FOOD_AND_DRINK_GROCERIES",
                    confidenceLevel: .veryHigh
                )
            ),
            Transaction(
                id: "t-5", accountId: "cc-1", amount: 14.99,
                date: Date(), name: "Netflix",
                merchantName: "Netflix",
                category: ["Service", "Subscription"],
                personalFinanceCategory: PersonalFinanceCategory(
                    primary: "ENTERTAINMENT", detailed: "ENTERTAINMENT_TV_AND_MOVIES",
                    confidenceLevel: .veryHigh
                )
            ),
        ]

        return vm
    }

    static var previews: some View {
        AnalysisCompleteView(
            snapshot: AnalysisSnapshot(
                monthlyFlow: MonthlyFlow(
                    income: 7250,
                    expenseBreakdown: ExpenseBreakdown(
                        housing: 1800,
                        food: 650,
                        transportation: 380,
                        utilities: 220,
                        insurance: 175,
                        subscriptions: 85,
                        healthcare: 120,
                        other: 95,
                        confidence: 0.88
                    ),
                    debtMinimums: 385
                ),
                position: FinancialPosition(
                    emergencyCash: 22800,
                    debtBalances: [
                        DebtAccount(
                            id: "cc-1", name: "Chase Sapphire",
                            type: .creditCard, balance: 1850,
                            apr: 0.2199, minimumPayment: 35
                        ),
                        DebtAccount(
                            id: "loan-1", name: "Auto Loan",
                            type: .autoLoan, balance: 14500,
                            apr: 0.069, minimumPayment: 350
                        ),
                    ],
                    investmentBalances: 81250,
                    monthlyInvestmentContributions: 500
                ),
                metadata: AnalysisMetadata(
                    monthsAnalyzed: 6,
                    accountsConnected: 5,
                    transactionsAnalyzed: 1247,
                    transactionsNeedingValidation: 3,
                    overallConfidence: 0.88,
                    lastUpdated: Date()
                )
            ),
            viewModel: richViewModel,
            onSeePlan: {},
            onAddAccount: {}
        )
        .preferredColorScheme(.dark)
    }
}
#endif
