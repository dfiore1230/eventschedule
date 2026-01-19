#if canImport(XCTest)
import Foundation
import XCTest

@testable import Planify

final class TalentModelTests: XCTestCase {
    func testTalentDecoding() throws {
        let json = """
        {
            "id": 1,
            "name": "John Smith",
            "description": "Award-winning artist",
            "website": "https://example.com",
            "profile_image_url": "https://example.com/photo.jpg",
            "email": "john@example.com"
        }
        """
        
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let talent = try decoder.decode(Talent.self, from: data)
        
        XCTAssertEqual(talent.id, 1)
        XCTAssertEqual(talent.name, "John Smith")
        XCTAssertEqual(talent.description, "Award-winning artist")
        XCTAssertEqual(talent.website, "https://example.com")
        XCTAssertEqual(talent.profileImageUrl, "https://example.com/photo.jpg")
        XCTAssertEqual(talent.email, "john@example.com")
    }
    
    func testTalentDecodingWithArrayLinks() throws {
        let json = """
        {
            "id": 2,
            "name": "Jane Doe",
            "auto_import_urls": ["https://example.com", "https://another.com"]
        }
        """
        
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let talent = try decoder.decode(Talent.self, from: data)
        
        XCTAssertEqual(talent.id, 2)
        XCTAssertEqual(talent.name, "Jane Doe")
        XCTAssertEqual(talent.autoImportUrls?.count, 2)
    }
    
    func testTalentEncoding() throws {
        let talent = Talent(
            id: 1,
            name: "Test Artist",
            website: "https://example.com",
            description: "A talented musician",
            profileImageUrl: "https://example.com/image.jpg"
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(talent)
        
        // Decode it back to verify
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Talent.self, from: data)
        
        XCTAssertEqual(decoded.id, talent.id)
        XCTAssertEqual(decoded.name, talent.name)
        XCTAssertEqual(decoded.website, talent.website)
        XCTAssertEqual(decoded.description, talent.description)
    }
    
    func testTalentDecodingWithInvalidURLs() throws {
        let json = """
        {
            "id": 3,
            "name": "Test",
            "auto_import_urls": ["not-a-url", "https://valid.com", "also invalid"]
        }
        """
        
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let talent = try decoder.decode(Talent.self, from: data)
        
        // Should include provided URLs as-is
        XCTAssertEqual(talent.autoImportUrls?.count, 3)
        XCTAssertEqual(talent.autoImportUrls?.contains("https://valid.com"), true)
    }
}
#endif
