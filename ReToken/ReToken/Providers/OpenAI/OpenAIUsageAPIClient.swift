import Foundation

struct OpenAIUsageSummary {
    let totalTokens: Int
    let totalRequests: Int
    let totalCostUSD: Double?
}

struct OpenAIUsageAPIClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchDailyUsage(
        adminKey: String,
        organizationID: String?,
        projectID: String?
    ) async throws -> OpenAIUsageSummary {
        async let usageResponse = performRequest(
            path: "/v1/organization/usage/completions",
            queryItems: usageQueryItems(projectID: projectID),
            adminKey: adminKey,
            organizationID: organizationID,
            projectID: projectID
        )

        async let costResponse = performRequest(
            path: "/v1/organization/costs",
            queryItems: costsQueryItems(projectID: projectID),
            adminKey: adminKey,
            organizationID: organizationID,
            projectID: projectID
        )

        let usageData = try await usageResponse
        let costsData = try await costResponse

        let usage = try JSONDecoder().decode(OpenAICompletionsUsageResponse.self, from: usageData)
        let costs = try JSONDecoder().decode(OpenAICostsResponse.self, from: costsData)

        let totalTokens = usage.data
            .flatMap(\.results)
            .reduce(0) { partialResult, result in
                partialResult + result.inputTokens + result.outputTokens
            }

        let totalRequests = usage.data
            .flatMap(\.results)
            .reduce(0) { $0 + $1.numModelRequests }

        let totalCostUSD = costs.data
            .flatMap(\.results)
            .reduce(0.0) { $0 + $1.amount.value }

        return OpenAIUsageSummary(
            totalTokens: totalTokens,
            totalRequests: totalRequests,
            totalCostUSD: totalCostUSD == 0 ? nil : totalCostUSD
        )
    }

    private func performRequest(
        path: String,
        queryItems: [URLQueryItem],
        adminKey: String,
        organizationID: String?,
        projectID: String?
    ) async throws -> Data {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.openai.com"
        components.path = path
        components.queryItems = queryItems

        guard let url = components.url else {
            throw OpenAIUsageAPIError.invalidRequest
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(adminKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let organizationID, organizationID.isEmpty == false {
            request.setValue(organizationID, forHTTPHeaderField: "OpenAI-Organization")
        }

        if let projectID, projectID.isEmpty == false {
            request.setValue(projectID, forHTTPHeaderField: "OpenAI-Project")
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIUsageAPIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorResponse = try? JSONDecoder().decode(OpenAIErrorEnvelope.self, from: data)
            throw OpenAIUsageAPIError.httpFailure(
                statusCode: httpResponse.statusCode,
                message: errorResponse?.error.message ?? "Unknown OpenAI error"
            )
        }

        return data
    }

    private func usageQueryItems(projectID: String?) -> [URLQueryItem] {
        var queryItems = commonQueryItems()
        if let projectID, projectID.isEmpty == false {
            queryItems.append(URLQueryItem(name: "project_ids[]", value: projectID))
        }
        return queryItems
    }

    private func costsQueryItems(projectID: String?) -> [URLQueryItem] {
        var queryItems = commonQueryItems()
        if let projectID, projectID.isEmpty == false {
            queryItems.append(URLQueryItem(name: "project_ids[]", value: projectID))
        }
        return queryItems
    }

    private func commonQueryItems(now: Date = .now) -> [URLQueryItem] {
        let endTime = Int(now.timeIntervalSince1970)
        let startTime = endTime - (24 * 60 * 60)

        return [
            URLQueryItem(name: "start_time", value: String(startTime)),
            URLQueryItem(name: "bucket_width", value: "1d"),
            URLQueryItem(name: "limit", value: "1")
        ]
    }
}

private struct OpenAICompletionsUsageResponse: Decodable {
    let data: [Bucket]

    struct Bucket: Decodable {
        let results: [Result]
    }

    struct Result: Decodable {
        let inputTokens: Int
        let outputTokens: Int
        let numModelRequests: Int

        private enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
            case numModelRequests = "num_model_requests"
        }
    }
}

private struct OpenAICostsResponse: Decodable {
    let data: [Bucket]

    struct Bucket: Decodable {
        let results: [Result]
    }

    struct Result: Decodable {
        let amount: Amount
    }

    struct Amount: Decodable {
        let value: Double
    }
}

private struct OpenAIErrorEnvelope: Decodable {
    let error: OpenAIErrorBody
}

private struct OpenAIErrorBody: Decodable {
    let message: String
}

private enum OpenAIUsageAPIError: LocalizedError {
    case invalidRequest
    case invalidResponse
    case httpFailure(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "Failed to build the OpenAI usage request"
        case .invalidResponse:
            return "Received an invalid response from OpenAI"
        case let .httpFailure(statusCode, message):
            return "OpenAI usage request failed (\(statusCode)): \(message)"
        }
    }
}
