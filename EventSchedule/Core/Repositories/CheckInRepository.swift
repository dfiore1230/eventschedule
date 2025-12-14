import Foundation

protocol CheckInRepositoryProtocol {
    func performCheckIn(_ checkIn: CheckIn, instance: InstanceProfile) async throws -> ScanResult
    func fetchCheckIns(eventId: String, instance: InstanceProfile) async throws -> [CheckIn]
    func scanTicket(code: String, eventId: String, gateId: String?, deviceId: String?, instance: InstanceProfile) async throws -> ScanResult
}

final class RemoteCheckInRepository: CheckInRepositoryProtocol {
    private let httpClient: HTTPClientProtocol
    
    init(httpClient: HTTPClientProtocol) {
        self.httpClient = httpClient
    }
    
    func performCheckIn(_ checkIn: CheckIn, instance: InstanceProfile) async throws -> ScanResult {
        struct CheckInRequest: Codable {
            let ticketId: String
            let ticketCode: String?
            let eventId: String
            let gateId: String?
            let deviceId: String?
            let action: String
            let timestamp: Date
            let idempotencyKey: String
            
            enum CodingKeys: String, CodingKey {
                case ticketId = "ticket_id"
                case ticketCode = "ticket_code"
                case eventId = "event_id"
                case gateId = "gate_id"
                case deviceId = "device_id"
                case action
                case timestamp = "ts"
                case idempotencyKey = "idempotency_key"
            }
        }
        
        let request = CheckInRequest(
            ticketId: checkIn.ticketId,
            ticketCode: checkIn.ticketCode,
            eventId: checkIn.eventId,
            gateId: checkIn.gateId,
            deviceId: checkIn.deviceId,
            action: checkIn.action.rawValue,
            timestamp: checkIn.timestamp,
            idempotencyKey: checkIn.idempotencyKey()
        )
        
        let result: ScanResult = try await httpClient.request(
            "api/checkins",
            method: .post,
            query: nil,
            body: request,
            instance: instance
        )
        return result
    }
    
    func fetchCheckIns(eventId: String, instance: InstanceProfile) async throws -> [CheckIn] {
        struct Response: Decodable { let data: [CheckIn] }
        // Try direct array first using the client's decoding; if that fails upstream it will throw.
        // We'll attempt the wrapped variant by asking for Response and returning its data.
        if let direct: [CheckIn] = try? await httpClient.request(
            "api/checkins",
            method: .get,
            query: ["event_id": eventId],
            body: Optional<CheckIn>.none,
            instance: instance
        ) {
            return direct
        }
        let wrapped: Response = try await httpClient.request(
            "api/checkins",
            method: .get,
            query: ["event_id": eventId],
            body: Optional<CheckIn>.none,
            instance: instance
        )
        return wrapped.data
    }
    
    func scanTicket(code: String, eventId: String, gateId: String?, deviceId: String?, instance: InstanceProfile) async throws -> ScanResult {
        // Create a check-in from the scanned code
        let checkIn = CheckIn(
            ticketId: code, // Will be resolved by backend
            ticketCode: code,
            eventId: eventId,
            gateId: gateId,
            deviceId: deviceId,
            action: .checkIn
        )
        
        return try await performCheckIn(checkIn, instance: instance)
    }
}
