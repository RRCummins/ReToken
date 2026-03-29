import Foundation
import XCTest
@testable import ReToken

@MainActor
final class OpenAIUsageAPIClientTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_711_634_800)

    override func tearDown() {
        super.tearDown()
        MockURLProtocol.requestHandler = nil
    }

    func testFetchUsageWindowsAggregatesTodayFiveHourWeekAndCosts() async throws {
        let requestQueue = DispatchQueue(label: "OpenAIUsageAPIClientTests.requests")
        var requests: [URLRequest] = []

        MockURLProtocol.requestHandler = { request in
            requestQueue.sync {
                requests.append(request)
            }

            guard let url = request.url,
                  let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                throw URLError(.badURL)
            }

            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer admin-key")
            XCTAssertEqual(request.value(forHTTPHeaderField: "OpenAI-Organization"), "org_123")
            XCTAssertEqual(request.value(forHTTPHeaderField: "OpenAI-Project"), "proj_456")
            XCTAssertTrue(components.queryItems?.contains(URLQueryItem(name: "project_ids[]", value: "proj_456")) == true)
            let queryItems = components.queryItems ?? []
            let startTime = try XCTUnwrap(queryItems.first(where: { $0.name == "start_time" })?.value)
            let endTime = try XCTUnwrap(queryItems.first(where: { $0.name == "end_time" })?.value)
            let bucketWidth = try XCTUnwrap(queryItems.first(where: { $0.name == "bucket_width" })?.value)
            let limit = try XCTUnwrap(queryItems.first(where: { $0.name == "limit" })?.value)
            let expectedTodayStart = Int(Calendar.autoupdatingCurrent.startOfDay(for: self.now).timeIntervalSince1970)
            let expectedTodayLimit = Int(
                ceil(self.now.timeIntervalSince(Calendar.autoupdatingCurrent.startOfDay(for: self.now)) / (60 * 60))
            )

            XCTAssertEqual(endTime, String(Int(self.now.timeIntervalSince1970)))

            let payload: String
            switch url.path {
            case "/v1/organization/usage/completions":
                switch (startTime, bucketWidth, limit) {
                case (String(expectedTodayStart), "1h", String(expectedTodayLimit)):
                    payload = """
                    {
                      "data": [
                        {
                          "results": [
                            { "input_tokens": 1000, "output_tokens": 400, "num_model_requests": 7 },
                            { "input_tokens": 10, "output_tokens": 5, "num_model_requests": 1 }
                          ]
                        }
                      ]
                    }
                    """
                case (String(1_711_616_800), "1h", "5"):
                    payload = """
                    {
                      "data": [
                        {
                          "results": [
                            { "input_tokens": 300, "output_tokens": 200, "num_model_requests": 3 }
                          ]
                        }
                      ]
                    }
                    """
                case (String(1_711_030_000), "1d", "7"):
                    payload = """
                    {
                      "data": [
                        {
                          "results": [
                            { "input_tokens": 5000, "output_tokens": 2000, "num_model_requests": 30 },
                            { "input_tokens": 400, "output_tokens": 100, "num_model_requests": 2 }
                          ]
                        }
                      ]
                    }
                    """
                default:
                    XCTFail("Unexpected usage request query: start=\(startTime) bucket=\(bucketWidth) limit=\(limit)")
                    throw URLError(.badServerResponse)
                }
            case "/v1/organization/costs":
                XCTAssertEqual(startTime, String(expectedTodayStart))
                XCTAssertEqual(bucketWidth, "1d")
                XCTAssertEqual(limit, "1")
                payload = """
                {
                  "data": [
                    {
                      "results": [
                        { "amount": { "value": 1.25 } },
                        { "amount": { "value": 0.75 } }
                      ]
                    }
                  ]
                }
                """
            default:
                throw URLError(.unsupportedURL)
            }

            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!

            return (response, Data(payload.utf8))
        }

        let client = OpenAIUsageAPIClient(session: makeMockSession())
        let summary = try await client.fetchUsageWindows(
            adminKey: "admin-key",
            organizationID: "org_123",
            projectID: "proj_456",
            now: now
        )

        XCTAssertEqual(summary.todayTokens, 1_415)
        XCTAssertEqual(summary.todayInputTokens, 1_010)
        XCTAssertEqual(summary.todayOutputTokens, 405)
        XCTAssertEqual(summary.fiveHourTokens, 500)
        XCTAssertEqual(summary.weekTokens, 7_500)
        XCTAssertEqual(summary.todayRequests, 8)
        XCTAssertEqual(summary.todayCostUSD, 2.0)

        let recordedPaths = requestQueue.sync {
            requests.compactMap(\.url?.path).sorted()
        }
        XCTAssertEqual(
            recordedPaths,
            [
                "/v1/organization/costs",
                "/v1/organization/usage/completions",
                "/v1/organization/usage/completions",
                "/v1/organization/usage/completions"
            ]
        )
    }

    func testFetchDailyUsageSurfacesHTTPFailures() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 401,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!

            let payload = Data(
                """
                {
                  "error": {
                    "message": "Bad admin key"
                  }
                }
                """.utf8
            )

            return (response, payload)
        }

        let client = OpenAIUsageAPIClient(session: makeMockSession())

        do {
            _ = try await client.fetchDailyUsage(
                adminKey: "bad-key",
                organizationID: nil,
                projectID: nil,
                now: now
            )
            XCTFail("Expected fetchDailyUsage to throw")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("401"))
            XCTAssertTrue(error.localizedDescription.contains("Bad admin key"))
        }
    }

    private func makeMockSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
