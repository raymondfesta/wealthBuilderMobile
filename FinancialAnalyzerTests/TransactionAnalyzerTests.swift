import XCTest
@testable import FinancialAnalyzer

final class TransactionAnalyzerTests: XCTestCase {

    // MARK: - Expense Breakdown Tests

    func testCategorizeExpenses_housingFromRent() {
        let transactions = [
            makeTransaction(pfc: "RENT_AND_UTILITIES", detailed: "RENT", amount: 1800)
        ]

        let breakdown = TransactionAnalyzer.categorizeExpenses(from: transactions, months: 1)

        XCTAssertEqual(breakdown.housing, 1800)
        XCTAssertEqual(breakdown.utilities, 0)
    }

    func testCategorizeExpenses_utilitiesFromRentAndUtilities() {
        let transactions = [
            makeTransaction(pfc: "RENT_AND_UTILITIES", detailed: "UTILITIES_GAS", amount: 100),
            makeTransaction(pfc: "RENT_AND_UTILITIES", detailed: "UTILITIES_ELECTRIC", amount: 150)
        ]

        let breakdown = TransactionAnalyzer.categorizeExpenses(from: transactions, months: 1)

        XCTAssertEqual(breakdown.housing, 0)
        XCTAssertEqual(breakdown.utilities, 250)
    }

    func testCategorizeExpenses_foodFromFoodAndDrink() {
        let transactions = [
            makeTransaction(pfc: "FOOD_AND_DRINK", detailed: "GROCERIES", amount: 400),
            makeTransaction(pfc: "FOOD_AND_DRINK", detailed: "RESTAURANTS", amount: 200)
        ]

        let breakdown = TransactionAnalyzer.categorizeExpenses(from: transactions, months: 1)

        XCTAssertEqual(breakdown.food, 600)
    }

    func testCategorizeExpenses_transportation() {
        let transactions = [
            makeTransaction(pfc: "TRANSPORTATION", detailed: "GAS", amount: 150),
            makeTransaction(pfc: "TRANSPORTATION", detailed: "PUBLIC_TRANSIT", amount: 50),
            makeTransaction(pfc: "TRAVEL", detailed: "AIRLINES", amount: 300)
        ]

        let breakdown = TransactionAnalyzer.categorizeExpenses(from: transactions, months: 1)

        XCTAssertEqual(breakdown.transportation, 500) // 150 + 50 + 300
    }

    func testCategorizeExpenses_subscriptions() {
        let transactions = [
            makeTransaction(pfc: "ENTERTAINMENT", detailed: "STREAMING_SERVICES", amount: 15),
            makeTransaction(pfc: "ENTERTAINMENT", detailed: "MUSIC_SUBSCRIPTION", amount: 10),
            makeTransaction(pfc: "GENERAL_SERVICES", detailed: "GYM_MEMBERSHIP", amount: 50)
        ]

        let breakdown = TransactionAnalyzer.categorizeExpenses(from: transactions, months: 1)

        XCTAssertEqual(breakdown.subscriptions, 75)
    }

    func testCategorizeExpenses_investmentsExcluded() {
        let transactions = [
            makeTransaction(pfc: "FOOD_AND_DRINK", detailed: "GROCERIES", amount: 400, bucket: .expenses),
            makeTransaction(pfc: "TRANSFER_OUT", detailed: "INVESTMENT_CONTRIBUTION", amount: 500, bucket: .invested)
        ]

        let breakdown = TransactionAnalyzer.categorizeExpenses(from: transactions, months: 1)

        XCTAssertEqual(breakdown.total, 400) // Investment should NOT be included
    }

    func testCategorizeExpenses_monthlyAverage() {
        let transactions = [
            makeTransaction(pfc: "FOOD_AND_DRINK", detailed: "GROCERIES", amount: 1200)
        ]

        // With 3 months, should divide by 3
        let breakdown = TransactionAnalyzer.categorizeExpenses(from: transactions, months: 3)

        XCTAssertEqual(breakdown.food, 400) // 1200 / 3
    }

    func testCategorizeExpenses_confidenceCalculation() {
        let transactions = [
            makeTransaction(pfc: "FOOD_AND_DRINK", detailed: "GROCERIES", amount: 100, confidence: .veryHigh),
            makeTransaction(pfc: "FOOD_AND_DRINK", detailed: "RESTAURANTS", amount: 50, confidence: .high),
            makeTransaction(pfc: "ENTERTAINMENT", detailed: "OTHER", amount: 25, confidence: .low),
            makeTransaction(pfc: "ENTERTAINMENT", detailed: "SPORTS", amount: 25, confidence: .medium)
        ]

        let breakdown = TransactionAnalyzer.categorizeExpenses(from: transactions, months: 1)

        // 2 out of 4 are high/veryHigh = 50%
        XCTAssertEqual(breakdown.confidence, 0.5, accuracy: 0.01)
    }

    func testCategorizeExpenses_emptyTransactions() {
        let breakdown = TransactionAnalyzer.categorizeExpenses(from: [], months: 1)

        XCTAssertEqual(breakdown.total, 0)
        XCTAssertEqual(breakdown.confidence, 0)
    }

    // MARK: - Expense Breakdown Model Tests

    func testExpenseBreakdown_totalCalculation() {
        let breakdown = ExpenseBreakdown(
            housing: 1000,
            food: 500,
            transportation: 300,
            utilities: 200,
            insurance: 100,
            subscriptions: 50,
            other: 25,
            confidence: 0.9
        )

        XCTAssertEqual(breakdown.total, 2175)
    }

    func testExpenseBreakdown_categoriesOnlyIncludesNonZero() {
        let breakdown = ExpenseBreakdown(
            housing: 1000,
            food: 0,
            transportation: 300,
            utilities: 0,
            insurance: 0,
            subscriptions: 50,
            other: 0,
            confidence: 0.8
        )

        XCTAssertEqual(breakdown.categories.count, 3) // housing, transportation, subscriptions
    }

    func testExpenseBreakdown_confidenceLevelHigh() {
        let breakdown = ExpenseBreakdown(
            housing: 1000, food: 500, transportation: 300,
            utilities: 200, insurance: 100, subscriptions: 50, other: 25,
            confidence: 0.90
        )

        XCTAssertEqual(breakdown.confidenceLevel, .high)
    }

    func testExpenseBreakdown_confidenceLevelMedium() {
        let breakdown = ExpenseBreakdown(
            housing: 1000, food: 500, transportation: 300,
            utilities: 200, insurance: 100, subscriptions: 50, other: 25,
            confidence: 0.75
        )

        XCTAssertEqual(breakdown.confidenceLevel, .medium)
    }

    func testExpenseBreakdown_confidenceLevelLow() {
        let breakdown = ExpenseBreakdown(
            housing: 1000, food: 500, transportation: 300,
            utilities: 200, insurance: 100, subscriptions: 50, other: 25,
            confidence: 0.50
        )

        XCTAssertEqual(breakdown.confidenceLevel, .low)
    }

    // MARK: - Monthly Flow Tests

    func testMonthlyFlow_discretionaryIncomeCalculation() {
        let breakdown = ExpenseBreakdown(
            housing: 1500, food: 500, transportation: 300,
            utilities: 200, insurance: 100, subscriptions: 50, other: 350,
            confidence: 0.85
        )

        let flow = MonthlyFlow(
            income: 5000,
            expenseBreakdown: breakdown,
            debtMinimums: 200
        )

        // 5000 - 3000 - 200 = 1800
        XCTAssertEqual(flow.discretionaryIncome, 1800)
    }

    func testMonthlyFlow_essentialExpensesFromBreakdown() {
        let breakdown = ExpenseBreakdown(
            housing: 1000, food: 500, transportation: 300,
            utilities: 200, insurance: 0, subscriptions: 0, other: 0,
            confidence: 0.9
        )

        let flow = MonthlyFlow(
            income: 5000,
            expenseBreakdown: breakdown,
            debtMinimums: 0
        )

        XCTAssertEqual(flow.essentialExpenses, 2000) // Uses breakdown.total
    }

    func testMonthlyFlow_legacyInitializerBackwardCompatibility() {
        let flow = MonthlyFlow(
            income: 5000,
            essentialExpenses: 3000,
            debtMinimums: 200
        )

        XCTAssertEqual(flow.essentialExpenses, 3000)
        XCTAssertEqual(flow.discretionaryIncome, 1800)
        XCTAssertFalse(flow.hasDetailedBreakdown)
    }

    func testMonthlyFlow_hasDetailedBreakdown() {
        let breakdown = ExpenseBreakdown(
            housing: 1000, food: 500, transportation: 300,
            utilities: 200, insurance: 0, subscriptions: 0, other: 0,
            confidence: 0.9
        )

        let flowWithBreakdown = MonthlyFlow(
            income: 5000,
            expenseBreakdown: breakdown,
            debtMinimums: 0
        )

        let flowWithoutBreakdown = MonthlyFlow(
            income: 5000,
            essentialExpenses: 2000,
            debtMinimums: 0
        )

        XCTAssertTrue(flowWithBreakdown.hasDetailedBreakdown)
        XCTAssertFalse(flowWithoutBreakdown.hasDetailedBreakdown)
    }

    func testMonthlyFlow_negativeDisposableIncome() {
        let flow = MonthlyFlow(
            income: 3000,
            essentialExpenses: 2500,
            debtMinimums: 800
        )

        XCTAssertEqual(flow.discretionaryIncome, -300)
        XCTAssertFalse(flow.isPositive)
    }

    // MARK: - Debt Minimums Tests

    func testCalculateDebtMinimums_creditCard() {
        let accounts = [
            makeBankAccount(type: "credit", balance: 5000)
        ]

        let minimums = TransactionAnalyzer.calculateDebtMinimums(accounts: accounts)

        // Credit cards: 2.5% of balance = $125
        XCTAssertEqual(minimums, 125, accuracy: 1)
    }

    func testCalculateDebtMinimums_studentLoan() {
        let accounts = [
            makeBankAccount(type: "loan", subtype: "student", balance: 30000)
        ]

        let minimums = TransactionAnalyzer.calculateDebtMinimums(accounts: accounts)

        // Student loans: 1% of balance = $300
        XCTAssertEqual(minimums, 300, accuracy: 1)
    }

    func testCalculateDebtMinimums_multiplDebts() {
        let accounts = [
            makeBankAccount(type: "credit", balance: 2000),   // 2.5% = $50
            makeBankAccount(type: "loan", subtype: "auto", balance: 15000) // 1.8% = $270
        ]

        let minimums = TransactionAnalyzer.calculateDebtMinimums(accounts: accounts)

        XCTAssertEqual(minimums, 320, accuracy: 5)
    }

    func testCalculateDebtMinimums_minimumForCreditCard() {
        let accounts = [
            makeBankAccount(type: "credit", balance: 500) // 2.5% = $12.50, but min is $25
        ]

        let minimums = TransactionAnalyzer.calculateDebtMinimums(accounts: accounts)

        XCTAssertEqual(minimums, 25, accuracy: 1)
    }

    // MARK: - Helper Methods

    private func makeTransaction(
        pfc: String,
        detailed: String,
        amount: Double,
        confidence: ConfidenceLevel = .high,
        bucket: BucketCategory = .expenses
    ) -> Transaction {
        let transaction = Transaction(
            id: UUID().uuidString,
            accountId: "test-account",
            amount: amount,
            date: Date(),
            name: "Test Transaction",
            merchantName: nil,
            category: [pfc],
            categoryId: nil,
            pending: false,
            transactionType: nil,
            iso_currency_code: "USD",
            personalFinanceCategory: PersonalFinanceCategory(
                primary: pfc,
                detailed: detailed,
                confidenceLevel: confidence
            ),
            userValidated: false,
            userCorrectedCategory: bucket == .invested ? .invested : nil
        )

        return transaction
    }

    private func makeBankAccount(
        type: String,
        subtype: String? = nil,
        balance: Double
    ) -> BankAccount {
        return BankAccount(
            itemId: "test-item",
            accountId: UUID().uuidString,
            name: "Test Account",
            type: type,
            subtype: subtype,
            currentBalance: balance,
            availableBalance: balance,
            limit: nil
        )
    }
}
