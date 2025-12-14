#if canImport(XCTest)
import Foundation
import XCTest

@testable import EventSchedule

final class CheckInModelTests: XCTestCase {
    func testCheckInCreation() {
        let checkIn = CheckIn(
            ticketId: "T123",
            ticketCode: "ABC-123",
            eventId: "E1",
            gateId: "Gate-A",
            deviceId: "Device-1",
            action: .checkIn
        )
        
        XCTAssertEqual(checkIn.ticketId, "T123")
        XCTAssertEqual(checkIn.ticketCode, "ABC-123")
        XCTAssertEqual(checkIn.eventId, "E1")
        XCTAssertEqual(checkIn.gateId, "Gate-A")
        XCTAssertEqual(checkIn.deviceId, "Device-1")
        XCTAssertEqual(checkIn.action, .checkIn)
        XCTAssertFalse(checkIn.isOffline)
        XCTAssertNil(checkIn.syncedAt)
    }
    
    func testIdempotencyKey() {
        let timestamp = Date(timeIntervalSince1970: 1000000)
        let checkIn = CheckIn(
            ticketId: "T123",
            eventId: "E1",
            deviceId: "Device-1",
            action: .checkIn,
            timestamp: timestamp
        )
        
        let key = checkIn.idempotencyKey()
        XCTAssertTrue(key.contains("Device-1"))
        XCTAssertTrue(key.contains("T123"))
        XCTAssertTrue(key.contains("1000000"))
    }
    
    func testCheckInDecoding() throws {
        let json = """
        {
            "id": "C123",
            "ticket_id": "T456",
            "ticket_code": "XYZ-789",
            "event_id": "E1",
            "gate_id": "Gate-B",
            "device_id": "Device-2",
            "action": "checkin",
            "timestamp": "2025-01-01T12:00:00Z",
            "is_offline": false
        }
        """
        
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let checkIn = try decoder.decode(CheckIn.self, from: data)
        
        XCTAssertEqual(checkIn.id, "C123")
        XCTAssertEqual(checkIn.ticketId, "T456")
        XCTAssertEqual(checkIn.ticketCode, "XYZ-789")
        XCTAssertEqual(checkIn.eventId, "E1")
        XCTAssertEqual(checkIn.gateId, "Gate-B")
        XCTAssertEqual(checkIn.deviceId, "Device-2")
        XCTAssertEqual(checkIn.action, .checkIn)
        XCTAssertFalse(checkIn.isOffline)
    }
    
    func testScanResultDecoding() throws {
        let json = """
        {
            "status": "admitted",
            "ticket_id": "T123",
            "holder_name": "John Doe",
            "event_id": "E1",
            "event_name": "Concert",
            "checked_in_at": "2025-01-01T19:00:00Z",
            "gate_id": "Gate-A",
            "server_time": "2025-01-01T19:00:01Z",
            "message": "Welcome!"
        }
        """
        
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let result = try decoder.decode(ScanResult.self, from: data)
        
        XCTAssertEqual(result.status, .admitted)
        XCTAssertEqual(result.ticketId, "T123")
        XCTAssertEqual(result.holder, "John Doe")
        XCTAssertEqual(result.eventId, "E1")
        XCTAssertEqual(result.eventName, "Concert")
        XCTAssertEqual(result.gateId, "Gate-A")
        XCTAssertEqual(result.message, "Welcome!")
        XCTAssertTrue(result.status.isSuccess)
    }
    
    func testScanResultStatuses() {
        let admitted = ScanResult(status: .admitted)
        XCTAssertTrue(admitted.status.isSuccess)
        XCTAssertEqual(admitted.status.displayName, "Admitted")
        
        let alreadyUsed = ScanResult(status: .alreadyUsed)
        XCTAssertFalse(alreadyUsed.status.isSuccess)
        XCTAssertEqual(alreadyUsed.status.displayName, "Already Used")
        
        let refunded = ScanResult(status: .refunded)
        XCTAssertFalse(refunded.status.isSuccess)
        XCTAssertEqual(refunded.status.displayName, "Refunded")
        
        let wrongEvent = ScanResult(status: .wrongEvent)
        XCTAssertFalse(wrongEvent.status.isSuccess)
        XCTAssertEqual(wrongEvent.status.displayName, "Wrong Event")
    }
    
    func testCheckInEncoding() throws {
        let checkIn = CheckIn(
            id: "C1",
            ticketId: "T1",
            ticketCode: "CODE-1",
            eventId: "E1",
            gateId: "Gate-A",
            deviceId: "Device-1",
            action: .checkIn,
            timestamp: Date(timeIntervalSince1970: 1000000),
            isOffline: true
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(checkIn)
        
        // Decode it back to verify
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(CheckIn.self, from: data)
        
        XCTAssertEqual(decoded.id, checkIn.id)
        XCTAssertEqual(decoded.ticketId, checkIn.ticketId)
        XCTAssertEqual(decoded.action, checkIn.action)
        XCTAssertEqual(decoded.isOffline, checkIn.isOffline)
    }
}
#endif
