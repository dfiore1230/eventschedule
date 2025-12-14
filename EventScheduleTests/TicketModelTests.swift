#if canImport(XCTest)
import Foundation
import XCTest

@testable import EventSchedule

final class TicketModelTests: XCTestCase {
    func testTicketDecoding() throws {
        let json = """
        {
            "id": "T123",
            "code": "ABC-123",
            "event_id": "E1",
            "event_name": "Concert Night",
            "ticket_type_id": "TT1",
            "ticket_type_name": "VIP",
            "holder_name": "John Doe",
            "holder_email": "john@example.com",
            "status": "valid",
            "price": "50.00",
            "currency": "USD",
            "seat": "A12",
            "zone": "VIP Section"
        }
        """
        
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let ticket = try decoder.decode(Ticket.self, from: data)
        
        XCTAssertEqual(ticket.id, "T123")
        XCTAssertEqual(ticket.code, "ABC-123")
        XCTAssertEqual(ticket.eventId, "E1")
        XCTAssertEqual(ticket.eventName, "Concert Night")
        XCTAssertEqual(ticket.ticketTypeName, "VIP")
        XCTAssertEqual(ticket.holderName, "John Doe")
        XCTAssertEqual(ticket.holderEmail, "john@example.com")
        XCTAssertEqual(ticket.status, .valid)
        XCTAssertEqual(ticket.price, Decimal(string: "50.00"))
        XCTAssertEqual(ticket.currency, "USD")
        XCTAssertEqual(ticket.seat, "A12")
        XCTAssertEqual(ticket.zone, "VIP Section")
    }
    
    func testTicketStatusDisplay() {
        let validTicket = Ticket(
            id: "1", code: "A", eventId: "E1", ticketTypeId: "T1",
            ticketTypeName: "General", status: .valid
        )
        XCTAssertEqual(validTicket.displayStatus, "Valid")
        XCTAssertTrue(validTicket.canCheckIn)
        XCTAssertFalse(validTicket.canCheckOut)
        
        let usedTicket = Ticket(
            id: "2", code: "B", eventId: "E1", ticketTypeId: "T1",
            ticketTypeName: "General", status: .used,
            checkedInAt: Date()
        )
        XCTAssertEqual(usedTicket.displayStatus, "Used")
        XCTAssertFalse(usedTicket.canCheckIn)
        XCTAssertTrue(usedTicket.canCheckOut)
        
        let refundedTicket = Ticket(
            id: "3", code: "C", eventId: "E1", ticketTypeId: "T1",
            ticketTypeName: "General", status: .refunded
        )
        XCTAssertEqual(refundedTicket.displayStatus, "Refunded")
        XCTAssertFalse(refundedTicket.canCheckIn)
        XCTAssertFalse(refundedTicket.canCheckOut)
    }
    
    func testTicketEncoding() throws {
        let ticket = Ticket(
            id: "T1",
            code: "TEST-123",
            eventId: "E1",
            ticketTypeId: "TT1",
            ticketTypeName: "General Admission",
            status: .valid,
            price: Decimal(string: "25.00"),
            currency: "USD"
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(ticket)
        
        // Decode it back to verify
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Ticket.self, from: data)
        
        XCTAssertEqual(decoded.id, ticket.id)
        XCTAssertEqual(decoded.code, ticket.code)
        XCTAssertEqual(decoded.status, ticket.status)
        XCTAssertEqual(decoded.price, ticket.price)
    }
    
    func testTicketPriceDecoding() throws {
        // Test numeric price
        let json1 = """
        {
            "id": "1", "code": "A", "event_id": "E1",
            "ticket_type_id": "T1", "ticket_type_name": "General",
            "status": "valid", "price": 25.50
        }
        """
        let data1 = json1.data(using: .utf8)!
        let ticket1 = try JSONDecoder().decode(Ticket.self, from: data1)
        XCTAssertEqual(ticket1.price, Decimal(string: "25.5"))
        
        // Test string price
        let json2 = """
        {
            "id": "2", "code": "B", "event_id": "E1",
            "ticket_type_id": "T1", "ticket_type_name": "General",
            "status": "valid", "price": "30.00"
        }
        """
        let data2 = json2.data(using: .utf8)!
        let ticket2 = try JSONDecoder().decode(Ticket.self, from: data2)
        XCTAssertEqual(ticket2.price, Decimal(string: "30.00"))
    }
}
#endif
