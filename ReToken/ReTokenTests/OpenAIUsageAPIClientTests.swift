import Foundation
import XCTest
@testable import ReToken

@MainActor
final class OpenAIUsageAPIClientTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        MockURLProtocol.requestHandler = nil
    }

    func testFetchDailyUsageAggregatesUsageAndCosts() async throws {
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
            XCTAssertTrue(components.queryItems?.contains(URLQueryItem(name: "bucket_width", value: "1d")) == true)
            XCTAssertTrue(components.queryItems?.contains(URLQueryItem(name: "limit", value: "1")) == true)
            XCTAssertTrue(components.queryItems?.contains(URLQueryItem(name: "project_ids[]", value: "proj_456")) == true)
            XCTAssertNotNil(components.queryItems?.first(where: { $0.name == "start_time" })?.value)

            let payload: String
            switch url.path {
            case "/v1/organization/usage/completions":
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
            case "/v1/organization/costs":
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
        let summary = try await client.fetchDailyUsage(
            adminKey: "admin-key",
            organizationID: "org_123",
            projectID: "proj_456"
        )

        XCTAssertEqual(summary.totalTokens, 1_415)
        XCTAssertEqual(summary.totalRequests, 8)
        XCTAssertEqual(summary.totalCostUSD, 2.0)

        let recordedPaths = requestQueue.sync {
            requests.compactMap(\.url?.path).sorted()
        }
        XCTAssertEqual(recordedPaths, ["/v1/organization/costs", "/v1/organization/usage/completions"])
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
                projectID: nil
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
