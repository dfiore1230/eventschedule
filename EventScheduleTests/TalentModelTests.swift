#if canImport(XCTest)
import Foundation
import XCTest

@testable import EventSchedule

final class TalentModelTests: XCTestCase {
    func testTalentDecoding() throws {
        let json = """
        {
            "id": "1",
            "name": "John Smith",
            "role": "Performer",
            "bio": "Award-winning artist",
            "links": {
                "website": "https://example.com",
                "twitter": "https://twitter.com/johnsmith"
            },
            "images": ["https://example.com/photo.jpg"],
            "contact": {
                "email": "john@example.com",
                "phone": "+1234567890"
            }
        }
        """
        
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let talent = try decoder.decode(Talent.self, from: data)
        
        XCTAssertEqual(talent.id, "1")
        XCTAssertEqual(talent.name, "John Smith")
        XCTAssertEqual(talent.role, "Performer")
        XCTAssertEqual(talent.bio, "Award-winning artist")
        XCTAssertEqual(talent.links.count, 2)
        XCTAssertEqual(talent.images.count, 1)
        XCTAssertNotNil(talent.contact)
        XCTAssertEqual(talent.contact?.email, "john@example.com")
    }
    
    func testTalentDecodingWithArrayLinks() throws {
        let json = """
        {
            "id": "2",
            "name": "Jane Doe",
            "links": ["https://example.com", "https://another.com"]
        }
        """
        
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let talent = try decoder.decode(Talent.self, from: data)
        
        XCTAssertEqual(talent.id, "2")
        XCTAssertEqual(talent.name, "Jane Doe")
        XCTAssertEqual(talent.links.count, 2)
        XCTAssertNotNil(talent.links["link0"])
        XCTAssertNotNil(talent.links["link1"])
    }
    
    func testTalentEncoding() throws {
        let talent = Talent(
            id: "1",
            name: "Test Artist",
            role: "Musician",
            bio: "A talented musician",
            links: ["website": URL(string: "https://example.com")!],
            images: [URL(string: "https://example.com/image.jpg")!]
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(talent)
        
        // Decode it back to verify
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Talent.self, from: data)
        
        XCTAssertEqual(decoded.id, talent.id)
        XCTAssertEqual(decoded.name, talent.name)
        XCTAssertEqual(decoded.role, talent.role)
        XCTAssertEqual(decoded.bio, talent.bio)
    }
    
    func testTalentDecodingWithInvalidURLs() throws {
        let json = """
        {
            "id": "3",
            "name": "Test",
            "links": ["not-a-url", "https://valid.com", "also invalid"]
        }
        """
        
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let talent = try decoder.decode(Talent.self, from: data)
        
        // Should only include valid URLs
        XCTAssertEqual(talent.links.count, 1)
        XCTAssertNotNil(talent.links["link1"])
    }
}
#endif
