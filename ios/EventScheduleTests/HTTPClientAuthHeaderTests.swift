import Foundation
#if canImport(XCTest)
import XCTest
@testable import EventSchedule

final class HTTPClientAuthHeaderTests: XCTestCase {
    final class MockURLProtocol: URLProtocol {
        static var handler: ((URLRequest) throws -> (Int, Data, [String: String]))?

        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

        override func startLoading() {
            guard let client = client else { return }
            do {
                let (status, data, headers) = try MockURLProtocol.handler?(request) ?? (200, Data(), [:])
                let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
                client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client.urlProtocol(self, didLoad: data)
                client.urlProtocolDidFinishLoading(self)
            } catch {
                client.urlProtocol(self, didFailWithError: error)
            }
        }

        override func stopLoading() {}
    }

    private func makeClient() -> HTTPClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        return HTTPClient(urlSession: session)
    }

    private func makeInstance() -> InstanceProfile {
        InstanceProfile(
            id: UUID(),
            displayName: "Test",
            baseURL: URL(string: "https://example.test/api")!,
            environment: .dev,
            authMethod: .sanctum,
            authEndpoints: nil,
            featureFlags: [:],
            minAppVersion: nil,
            rateLimits: nil,
            tokenIdentifier: nil,
            theme: nil
        )
    }

    private struct EchoDTO: Codable, Equatable { let ok: Bool }

    func testSendsAPIKeyHeader() async throws {
        let client = makeClient()
        let instance = makeInstance()

        APIKeyStore.shared.save(apiKey: "abc123", for: instance)

        MockURLProtocol.handler = { request in
            let sentKey = request.value(forHTTPHeaderField: "X-API-Key")
            XCTAssertEqual(sentKey, "abc123")
            let body = try JSONEncoder().encode(EchoDTO(ok: true))
            return (200, body, ["Content-Type": "application/json"])
        }

        let echo: EchoDTO = try await client.request("/ping", method: .get, query: nil, body: Optional<String>.none, instance: instance)
        XCTAssertTrue(echo.ok)

        APIKeyStore.shared.clear(for: instance)
    }

    func testHandlesUnauthorized() async throws {
        let client = makeClient()
        let instance = makeInstance()

        MockURLProtocol.handler = { _ in
            return (401, Data(), [:])
        }

        do {
            let _: EchoDTO = try await client.request("/secure", method: .get, query: nil, body: Optional<String>.none, instance: instance)
            XCTFail("Expected unauthorized error to be thrown")
        } catch let error as APIError {
            XCTAssertEqual(error, APIError.unauthorized)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
#endif
