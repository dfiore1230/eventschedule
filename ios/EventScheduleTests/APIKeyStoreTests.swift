#if canImport(XCTest)
import Foundation
import XCTest

@testable import EventSchedule

final class APIKeyStoreTests: XCTestCase {
    private func makeInstance(url: String = "https://example.test") -> InstanceProfile {
        InstanceProfile(
            id: UUID(),
            displayName: "Test",
            baseURL: URL(string: url)!,
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

    func testSaveAndLoad() throws {
        let instance = makeInstance()
        let key = "test-key-123"

        APIKeyStore.shared.clear(for: instance)
        XCTAssertNil(APIKeyStore.shared.load(for: instance))

        APIKeyStore.shared.save(apiKey: key, for: instance)
        let loaded = APIKeyStore.shared.load(for: instance)
        XCTAssertEqual(loaded, key)

        APIKeyStore.shared.clear(for: instance)
        XCTAssertNil(APIKeyStore.shared.load(for: instance))
    }

    func testSeparateInstances() throws {
        let a = makeInstance(url: "https://a.example.test")
        let b = makeInstance(url: "https://b.example.test")

        APIKeyStore.shared.clear(for: a)
        APIKeyStore.shared.clear(for: b)

        APIKeyStore.shared.save(apiKey: "a-key", for: a)
        APIKeyStore.shared.save(apiKey: "b-key", for: b)

        XCTAssertEqual(APIKeyStore.shared.load(for: a), "a-key")
        XCTAssertEqual(APIKeyStore.shared.load(for: b), "b-key")

        APIKeyStore.shared.clear(for: a)
        APIKeyStore.shared.clear(for: b)
    }
}
#endif
