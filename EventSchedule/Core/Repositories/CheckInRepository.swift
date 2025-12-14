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
        let url = instance.baseURL.appendingPathComponent("/api/checkins")
        
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
        
        let body = try JSONEncoder.iso8601.encode(request)
        let data = try await httpClient.post(url: url, body: body, instance: instance)
        return try JSONDecoder.iso8601.decode(ScanResult.self, from: data)
    }
    
    func fetchCheckIns(eventId: String, instance: InstanceProfile) async throws -> [CheckIn] {
        guard var components = URLComponents(url: instance.baseURL.appendingPathComponent("/api/checkins"), resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }
        components.queryItems = [URLQueryItem(name: "event_id", value: eventId)]
        
        guard let url = components.url else {
            throw APIError.invalidURL
        }
        
        let data = try await httpClient.get(url: url, instance: instance)
        
        // Try to decode as array directly first
        if let checkIns = try? JSONDecoder.iso8601.decode([CheckIn].self, from: data) {
            return checkIns
        }
        
        // Try to decode as wrapped response with 'data' key
        struct Response: Decodable {
            let data: [CheckIn]
        }
        
        let response = try JSONDecoder.iso8601.decode(Response.self, from: data)
        return response.data
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

// Convenience extensions for JSONDecoder and JSONEncoder
private extension JSONDecoder {
    static let iso8601: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

private extension JSONEncoder {
    static let iso8601: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}
