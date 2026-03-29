import Foundation

struct OpenAIUsageSummary {
    let todayTokens: Int
    let todayInputTokens: Int
    let todayOutputTokens: Int
    let fiveHourTokens: Int
    let weekTokens: Int
    let todayRequests: Int
    let todayCostUSD: Double?

    var totalTokens: Int { todayTokens }
    var totalRequests: Int { todayRequests }
    var totalCostUSD: Double? { todayCostUSD }
}

struct OpenAIUsageAPIClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchUsageWindows(
        adminKey: String,
        organizationID: String?,
        projectID: String?,
        now: Date = .now
    ) async throws -> OpenAIUsageSummary {
        let calendar = Calendar.autoupdatingCurrent
        let startOfDay = calendar.startOfDay(for: now)
        let fiveHourBoundary = now.addingTimeInterval(-(5 * 60 * 60))
        let weekBoundary = now.addingTimeInterval(-(7 * 24 * 60 * 60))

        async let todayUsage = fetchUsageAggregate(
            startTime: startOfDay,
            endTime: now,
            bucketWidth: .hour,
            adminKey: adminKey,
            organizationID: organizationID,
            projectID: projectID
        )

        async let fiveHourUsage = fetchUsageAggregate(
            startTime: fiveHourBoundary,
            endTime: now,
            bucketWidth: .hour,
            adminKey: adminKey,
            organizationID: organizationID,
            projectID: projectID
        )

        async let weekUsage = fetchUsageAggregate(
            startTime: weekBoundary,
            endTime: now,
            bucketWidth: .day,
            adminKey: adminKey,
            organizationID: organizationID,
            projectID: projectID
        )

        async let costResponse = performRequest(
            path: "/v1/organization/costs",
            queryItems: costsQueryItems(
                startTime: startOfDay,
                endTime: now,
                bucketWidth: .day,
                projectID: projectID
            ),
            adminKey: adminKey,
            organizationID: organizationID,
            projectID: projectID
        )

        let (todayUsageSummary, fiveHourUsageSummary, weekUsageSummary, costsData) = try await (
            todayUsage,
            fiveHourUsage,
            weekUsage,
            costResponse
        )

        let costs = try JSONDecoder().decode(OpenAICostsResponse.self, from: costsData)
        let totalCostUSD = costs.data
            .flatMap(\.results)
            .reduce(0.0) { $0 + $1.amount.value }

        return OpenAIUsageSummary(
            todayTokens: todayUsageSummary.tokens,
            todayInputTokens: todayUsageSummary.inputTokens,
            todayOutputTokens: todayUsageSummary.outputTokens,
            fiveHourTokens: fiveHourUsageSummary.tokens,
            weekTokens: weekUsageSummary.tokens,
            todayRequests: todayUsageSummary.requests,
            todayCostUSD: totalCostUSD == 0 ? nil : totalCostUSD
        )
    }

    func fetchDailyUsage(
        adminKey: String,
        organizationID: String?,
        projectID: String?,
        now: Date = .now
    ) async throws -> OpenAIUsageSummary {
        try await fetchUsageWindows(
            adminKey: adminKey,
            organizationID: organizationID,
            projectID: projectID,
            now: now
        )
    }

    private func fetchUsageAggregate(
        startTime: Date,
        endTime: Date,
        bucketWidth: OpenAIUsageBucketWidth,
        adminKey: String,
        organizationID: String?,
        projectID: String?
    ) async throws -> OpenAIUsageAggregate {
        let usageResponse = try await performRequest(
            path: "/v1/organization/usage/completions",
            queryItems: usageQueryItems(
                startTime: startTime,
                endTime: endTime,
                bucketWidth: bucketWidth,
                projectID: projectID
            ),
            adminKey: adminKey,
            organizationID: organizationID,
            projectID: projectID
        )

        let usage = try JSONDecoder().decode(OpenAICompletionsUsageResponse.self, from: usageResponse)
        let tokens = usage.data
            .flatMap(\.results)
            .reduce(0) { partialResult, result in
                partialResult + result.inputTokens + result.outputTokens
            }
        let inputTokens = usage.data
            .flatMap(\.results)
            .reduce(0) { $0 + $1.inputTokens }
        let outputTokens = usage.data
            .flatMap(\.results)
            .reduce(0) { $0 + $1.outputTokens }

        let requests = usage.data
            .flatMap(\.results)
            .reduce(0) { $0 + $1.numModelRequests }

        return OpenAIUsageAggregate(
            tokens: tokens,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            requests: requests
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

    private func usageQueryItems(
        startTime: Date,
        endTime: Date,
        bucketWidth: OpenAIUsageBucketWidth,
        projectID: String?
    ) -> [URLQueryItem] {
        var queryItems = commonQueryItems(
            startTime: startTime,
            endTime: endTime,
            bucketWidth: bucketWidth
        )
        if let projectID, projectID.isEmpty == false {
            queryItems.append(URLQueryItem(name: "project_ids[]", value: projectID))
        }
        return queryItems
    }

    private func costsQueryItems(
        startTime: Date,
        endTime: Date,
        bucketWidth: OpenAIUsageBucketWidth,
        projectID: String?
    ) -> [URLQueryItem] {
        var queryItems = commonQueryItems(
            startTime: startTime,
            endTime: endTime,
            bucketWidth: bucketWidth
        )
        if let projectID, projectID.isEmpty == false {
            queryItems.append(URLQueryItem(name: "project_ids[]", value: projectID))
        }
        return queryItems
    }

    private func commonQueryItems(
        startTime: Date,
        endTime: Date,
        bucketWidth: OpenAIUsageBucketWidth
    ) -> [URLQueryItem] {
        let startTimestamp = Int(startTime.timeIntervalSince1970)
        let endTimestamp = Int(endTime.timeIntervalSince1970)
        let bucketLimit = max(
            1,
            min(
                bucketWidth.maximumLimit,
                Int(ceil(endTime.timeIntervalSince(startTime) / bucketWidth.timeInterval))
            )
        )

        return [
            URLQueryItem(name: "start_time", value: String(startTimestamp)),
            URLQueryItem(name: "end_time", value: String(endTimestamp)),
            URLQueryItem(name: "bucket_width", value: bucketWidth.rawValue),
            URLQueryItem(name: "limit", value: String(bucketLimit))
        ]
    }
}

private struct OpenAIUsageAggregate {
    let tokens: Int
    let inputTokens: Int
    let outputTokens: Int
    let requests: Int
}

private enum OpenAIUsageBucketWidth: String {
    case hour = "1h"
    case day = "1d"

    var timeInterval: TimeInterval {
        switch self {
        case .hour:
            return 60 * 60
        case .day:
            return 24 * 60 * 60
        }
    }

    var maximumLimit: Int {
        switch self {
        case .hour:
            return 168
        case .day:
            return 31
        }
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
