import Foundation
import LinkKit

@MainActor
class PlaidService: ObservableObject {
    @Published var isLinkActive = false
    @Published var linkedAccounts: [BankAccount] = []
    @Published var error: PlaidError?

    private let baseURL: String
    private var linkHandler: Handler?

    init(baseURL: String = "http://localhost:3000") {
        self.baseURL = baseURL
    }

    // MARK: - Link Token Creation

    func createLinkToken() async throws -> String {
        let endpoint = "\(baseURL)/api/plaid/create_link_token"

        guard let url = URL(string: endpoint) else {
            throw PlaidError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PlaidError.networkError
        }

        let linkTokenResponse = try JSONDecoder().decode(LinkTokenResponse.self, from: data)
        return linkTokenResponse.linkToken
    }

    // MARK: - Plaid Link Flow

    func presentPlaidLink(linkToken: String, from viewController: UIViewController?) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            var configuration = LinkTokenConfiguration(token: linkToken) { success in
                Task {
                    do {
                        try await self.exchangePublicToken(success.publicToken)
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }

            configuration.onExit = { exit in
                if let error = exit.error {
                    continuation.resume(throwing: PlaidError.linkExited(error.localizedDescription))
                } else {
                    continuation.resume(throwing: PlaidError.userCancelled)
                }
            }

            let result = Plaid.create(configuration)

            switch result {
            case .success(let handler):
                self.linkHandler = handler
                if let vc = viewController {
                    handler.open(presentUsing: .viewController(vc))
                } else {
                    handler.open(presentUsing: .default)
                }
            case .failure(let error):
                continuation.resume(throwing: PlaidError.linkCreationFailed(error.localizedDescription))
            }
        }
    }

    // MARK: - Token Exchange

    private func exchangePublicToken(_ publicToken: String) async throws {
        let endpoint = "\(baseURL)/api/plaid/exchange_public_token"

        guard let url = URL(string: endpoint) else {
            throw PlaidError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["public_token": publicToken]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PlaidError.tokenExchangeFailed
        }

        let tokenResponse = try JSONDecoder().decode(AccessTokenResponse.self, from: data)

        // Store access token securely
        try KeychainService.shared.save(
            tokenResponse.accessToken,
            for: tokenResponse.itemId
        )
    }

    // MARK: - Fetch Accounts

    func fetchAccounts(accessToken: String) async throws -> [BankAccount] {
        let endpoint = "\(baseURL)/api/plaid/accounts"

        guard let url = URL(string: endpoint) else {
            throw PlaidError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["access_token": accessToken]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PlaidError.accountFetchFailed
        }

        let accountsResponse = try JSONDecoder().decode(AccountsResponse.self, from: data)
        return accountsResponse.accounts
    }

    // MARK: - Fetch Transactions

    func fetchTransactions(
        accessToken: String,
        startDate: Date,
        endDate: Date
    ) async throws -> [Transaction] {
        let endpoint = "\(baseURL)/api/plaid/transactions"

        guard let url = URL(string: endpoint) else {
            throw PlaidError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let body: [String: String] = [
            "access_token": accessToken,
            "start_date": dateFormatter.string(from: startDate),
            "end_date": dateFormatter.string(from: endDate)
        ]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PlaidError.transactionFetchFailed
        }

        let transactionsResponse = try JSONDecoder().decode(TransactionsResponse.self, from: data)
        return transactionsResponse.transactions
    }
}

// MARK: - Response Models

private struct LinkTokenResponse: Decodable {
    let linkToken: String

    enum CodingKeys: String, CodingKey {
        case linkToken = "link_token"
    }
}

private struct AccessTokenResponse: Decodable {
    let accessToken: String
    let itemId: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case itemId = "item_id"
    }
}

private struct AccountsResponse: Decodable {
    let accounts: [BankAccount]
}

private struct TransactionsResponse: Decodable {
    let transactions: [Transaction]
}

// MARK: - Error Handling

enum PlaidError: LocalizedError {
    case invalidURL
    case networkError
    case tokenExchangeFailed
    case accountFetchFailed
    case transactionFetchFailed
    case linkCreationFailed(String)
    case linkExited(String)
    case userCancelled

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API endpoint"
        case .networkError:
            return "Network connection failed"
        case .tokenExchangeFailed:
            return "Failed to exchange token"
        case .accountFetchFailed:
            return "Failed to fetch accounts"
        case .transactionFetchFailed:
            return "Failed to fetch transactions"
        case .linkCreationFailed(let message):
            return "Link creation failed: \(message)"
        case .linkExited(let message):
            return "Link exited: \(message)"
        case .userCancelled:
            return "User cancelled the link process"
        }
    }
}
