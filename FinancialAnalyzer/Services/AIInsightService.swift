import Foundation

/// Service for fetching AI-powered financial insights from backend
class AIInsightService {
    static let shared = AIInsightService()

    private let baseURL: String

    init(baseURL: String = AppConfig.baseURL) {
        self.baseURL = baseURL
    }

    /// Fetches AI insight for a purchase decision
    func getPurchaseInsight(
        amount: Double,
        merchantName: String,
        category: String,
        budgetStatus: BudgetStatusContext,
        spendingPattern: SpendingPatternContext?
    ) async throws -> String {
        guard let url = URL(string: "\(baseURL)/api/ai/purchase-insight") else {
            throw AIInsightError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30 // 30 seconds for AI response

        // Build request body
        let requestBody: [String: Any] = [
            "amount": amount,
            "merchantName": merchantName,
            "category": category,
            "budgetStatus": [
                "currentSpent": budgetStatus.currentSpent,
                "limit": budgetStatus.limit,
                "remaining": budgetStatus.remaining,
                "daysRemaining": budgetStatus.daysRemaining
            ],
            "spendingPattern": spendingPattern.map { pattern in
                [
                    "averageAmount": pattern.averageAmount,
                    "frequency": pattern.frequency
                ]
            } ?? [:]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        print("🤖 [AIInsight] Requesting insight for \(merchantName) $\(amount)")

        // Make network request with error wrapping
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as NSError {
            if error.code == NSURLErrorTimedOut {
                throw AIInsightError.timeout
            }
            throw AIInsightError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIInsightError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            print("❌ [AIInsight] Failed with status: \(httpResponse.statusCode)")
            throw AIInsightError.serverError(statusCode: httpResponse.statusCode)
        }

        // Parse response
        let jsonResponse = try JSONDecoder().decode(AIInsightResponse.self, from: data)

        print("✅ [AIInsight] Received insight (\(jsonResponse.usage.totalTokens) tokens)")

        return jsonResponse.insight ?? jsonResponse.explanation ?? "No insight available"
    }

    /// Fetches AI recommendation for savings allocation
    func getSavingsRecommendation(
        surplusAmount: Double,
        monthlyExpenses: Double,
        currentSavings: Double,
        goals: [GoalContext]
    ) async throws -> String {
        guard let url = URL(string: "\(baseURL)/api/ai/savings-recommendation") else {
            throw AIInsightError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let requestBody: [String: Any] = [
            "surplusAmount": surplusAmount,
            "monthlyExpenses": monthlyExpenses,
            "currentSavings": currentSavings,
            "goals": goals.map { goal in
                [
                    "name": goal.name,
                    "current": goal.current,
                    "target": goal.target,
                    "priority": goal.priority
                ]
            }
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        print("🤖 [AIInsight] Requesting savings recommendation for $\(surplusAmount) surplus")

        // Make network request with error wrapping
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as NSError {
            if error.code == NSURLErrorTimedOut {
                throw AIInsightError.timeout
            }
            throw AIInsightError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIInsightError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            print("❌ [AIInsight] Failed with status: \(httpResponse.statusCode)")
            throw AIInsightError.serverError(statusCode: httpResponse.statusCode)
        }

        let jsonResponse = try JSONDecoder().decode(AIInsightResponse.self, from: data)

        print("✅ [AIInsight] Received savings recommendation (\(jsonResponse.usage.totalTokens) tokens)")

        return jsonResponse.insight ?? jsonResponse.explanation ?? "No recommendation available"
    }

    /// Fetches AI explanation for allocation change
    func explainAllocationChange(
        bucketType: String,
        oldAmount: Double,
        newAmount: Double,
        monthlyIncome: Double,
        impactedBuckets: [(name: String, change: Double)]
    ) async throws -> String {
        guard let url = URL(string: "\(baseURL)/api/ai/explain-allocation-change") else {
            throw AIInsightError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let impactedBucketsArray = impactedBuckets.map { bucket in
            ["name": bucket.name, "change": bucket.change]
        }

        let requestBody: [String: Any] = [
            "bucketType": bucketType,
            "oldAmount": oldAmount,
            "newAmount": newAmount,
            "monthlyIncome": monthlyIncome,
            "impactedBuckets": impactedBucketsArray
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        print("🤖 [AIInsight] Requesting allocation change explanation for \(bucketType)")

        // Make network request with error wrapping
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as NSError {
            if error.code == NSURLErrorTimedOut {
                throw AIInsightError.timeout
            }
            throw AIInsightError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIInsightError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            print("❌ [AIInsight] Failed with status: \(httpResponse.statusCode)")
            throw AIInsightError.serverError(statusCode: httpResponse.statusCode)
        }

        let jsonResponse = try JSONDecoder().decode(AIInsightResponse.self, from: data)

        print("✅ [AIInsight] Received explanation (\(jsonResponse.usage.totalTokens) tokens)")

        return jsonResponse.explanation ?? jsonResponse.insight ?? "Unable to generate explanation"
    }
}

// MARK: - Request Context Models

struct BudgetStatusContext {
    let currentSpent: Double
    let limit: Double
    let remaining: Double
    let daysRemaining: Int
}

struct SpendingPatternContext {
    let averageAmount: Double
    let frequency: Double
}

struct GoalContext {
    let name: String
    let current: Double
    let target: Double
    let priority: String
}

// MARK: - Response Models

struct AIInsightResponse: Codable {
    let insight: String?
    let explanation: String?
    let usage: TokenUsage
}

struct TokenUsage: Codable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int

    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

// MARK: - Errors

enum AIInsightError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(statusCode: Int)
    case networkError(Error)
    case timeout

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid AI service URL configuration"
        case .invalidResponse:
            return "Invalid response from AI service"
        case .serverError(let code):
            return "AI service error (status: \(code))"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .timeout:
            return "AI request timed out. Please try again."
        }
    }
}
