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
            let eventId: Int?
            let attendeeName: String?
            let gateId: String?
            let deviceId: String?
            let action: String
            let timestamp: Date
            let idempotencyKey: String
            
            enum CodingKeys: String, CodingKey {
                case ticketId = "ticket_id"
                case ticketCode = "ticket_code"
                case eventId = "event_id"
                case attendeeName = "attendee_name"
                case gateId = "gate_id"
                case deviceId = "device_id"
                case action
                case timestamp = "ts"
                case idempotencyKey = "idempotency_key"
            }
        }
        
        let normalizedEventId = Self.normalizeEventId(checkIn.eventId)

        let request = CheckInRequest(
            ticketId: checkIn.ticketId,
            ticketCode: checkIn.ticketCode,
            eventId: normalizedEventId,
            attendeeName: checkIn.attendeeName ?? "Unknown",
            gateId: checkIn.gateId,
            deviceId: checkIn.deviceId,
            action: checkIn.action.rawValue,
            timestamp: checkIn.timestamp,
            idempotencyKey: checkIn.idempotencyKey()
        )
        
        let result: ScanResult = try await httpClient.request(
            "/api/checkins",
            method: .post,
            query: nil,
            body: request,
            instance: instance,
            additionalHeaders: nil
        )
        return result
    }
    
    func fetchCheckIns(eventId: String, instance: InstanceProfile) async throws -> [CheckIn] {
        struct Response: Decodable { let data: [CheckIn] }
        // Try direct array first using the client's decoding; if that fails upstream it will throw.
        // We'll attempt the wrapped variant by asking for Response and returning its data.
        if let direct: [CheckIn] = try? await httpClient.request(
            "/api/checkins",
            method: .get,
            query: ["event_id": eventId],
            body: Optional<CheckIn>.none,
            instance: instance,
            additionalHeaders: nil
        ) {
            return direct
        }
        let wrapped: Response = try await httpClient.request(
            "/api/checkins",
            method: .get,
            query: ["event_id": eventId],
            body: Optional<CheckIn>.none,
            instance: instance,
            additionalHeaders: nil
        )
        return wrapped.data
    }
    
    func scanTicket(code: String, eventId: String, gateId: String?, deviceId: String?, instance: InstanceProfile) async throws -> ScanResult {
        // Parse QR code - can be either:
        // 1. Plain ticket code: "wk8wfyzjrbrdv5rxvjxjzpx9ggum6uxl"
        // 2. Legacy URL format: "https://domain.com/ticket/view/{event_id}/{ticket_code}"
        
        var ticketCode: String = code.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Try parsing as URL first (legacy format)
        if let url = URL(string: code) {
            let pathComponents = url.pathComponents.filter { $0 != "/" }
            if pathComponents.count >= 4 && pathComponents[0] == "ticket" && pathComponents[1] == "view" {
                // Legacy URL format: extract ticket code from path
                var extracted = pathComponents[3]
                if let decoded = extracted.removingPercentEncoding { extracted = decoded }
                ticketCode = extracted
                // Extract event_id from path if needed (not used currently)
            }
        }
        // Otherwise, treat the whole code as the ticket code (new format)
        
        struct ScanResponse: Codable {
            let data: ScanData
        }

        struct ScanData: Codable {
            let sale_id: Int
            let entry_id: Int
            let scanned_at: String
            let sale: SaleDetails
        }

        struct SaleDetails: Codable {
            let id: Int
            let status: String
            let name: String
            let email: String
            let event_id: Int
            let event: EventDetails?
            let tickets: [TicketDetails]
        }

        struct EventDetails: Codable {
            let id: String
            let url: String?
            let slug: String?
            let name: String
            let description: String?
            let description_html: String?
            let starts_at: String?
            let duration: Int?
            let timezone: String?
            let venue_id: String?
            let venue: VenueDetails?
            let tickets_enabled: Bool?
            let ticket_currency_code: String?
            let total_tickets_mode: String?
            let ticket_notes: String?
            let ticket_notes_html: String?
            let registration_url: String?
            let event_url: String?
            let payment_method: String?
            let payment_instructions: String?
            let payment_instructions_html: String?
            let flyer_image_id: String?
            let flyer_image_url: String?
            let category: CategoryDetails?
            let has_password: Bool?
            let members: [String]?
            let tickets: [EventTicketDetails]?
            let schedules: [ScheduleDetails]?
            let curator_role: String?
        }

        struct VenueDetails: Codable {
            let id: String
            let url: String?
            let type: String?
            let subdomain: String?
            let name: String?
            let email: String?
            let website: String?
            let description: String?
            let timezone: String?
            let language_code: String?
            let country_code: String?
            let plan_type: String?
            let plan_expires: String?
            let contacts: [String]?
            let import_config: ImportConfigDetails?
            let accept_requests: Bool?
            let request_terms: String?
            let youtube_links: [String]?
            let groups: [String]?
            let address1: String?
            let address2: String?
            let city: String?
            let state: String?
            let postal_code: String?
            let rooms: [RoomDetails]?
        }

        struct ImportConfigDetails: Codable {
            let urls: [String]?
            let cities: [String]?
        }

        struct RoomDetails: Codable {
            let id: String?
            let name: String?
            let details: String?
        }

        struct CategoryDetails: Codable {
            let id: Int?
            let name: String?
        }

        struct EventTicketDetails: Codable {
            let id: String?
            let type: String?
            let price: String?
            let quantity: Int?
            let sold: [String: Int]?
            let description: String?
        }

        struct ScheduleDetails: Codable {
            let id: String?
            let name: String?
            let type: String?
            let subdomain: String?
            let pivot: PivotDetails?
        }

        struct PivotDetails: Codable {
            let group_id: String?
            let is_accepted: Int?
        }

        struct TicketDetails: Codable {
            let id: Int
            let ticket_id: Int
            let quantity: Int
            let usage_status: String
        }
        
        // UITest helper: allow injecting specific server responses by using special test codes.
        // When running with --uitesting, a code starting with "UITEST_404" will simulate a 404 Not Found
        // so we can deterministically exercise the client-side handling without hitting the network.
        // Also support a 419/unauthorized simulation via a code starting with "UITEST_419" which throws
        // an .unauthorized APIError to exercise the unauthorized handling path.
        // Support a "UITEST_2XX_MALFORMED" prefix to simulate a successful (2xx) response that
        // contains an unexpected/malformed body; the client should fall back to a generic success
        // result and log the decode issue to the console (UI must not show raw bodies).
        if ProcessInfo.processInfo.arguments.contains("--uitesting") {
            if ticketCode.starts(with: "UITEST_404") {
                throw APIError.serverError(statusCode: 404, message: "Ticket not found (UITest)")
            }
            if ticketCode.starts(with: "UITEST_419") {
                throw APIError.unauthorized
            }
            if ticketCode.starts(with: "UITEST_2XX_MALFORMED") {
                // Simulate the fallback path: log an error and return a generic admitted result.
                DebugLogger.error("UITest: Simulating malformed 2xx response for code \(ticketCode)")
                return ScanResult(status: .admitted, message: "Ticket scanned (server confirmed).")
            }
        }

        // Try to pre-fetch sale_ticket_id to assist backend scan resolution (optional)
        var resolvedSaleTicketId: Int? = nil
        do {
            let ticketRepository = RemoteTicketRepository(httpClient: httpClient)
            let (sales, _) = try await ticketRepository.searchPage(eventId: nil, query: ticketCode, page: 1, perPage: 1, instance: instance)
            if let sale = sales.first {
                resolvedSaleTicketId = sale.tickets.first?.id
            }
        } catch {
            // Non-fatal: proceed without sale_ticket_id
        }
        
        do {
            // Use the proper API endpoint: POST /api/tickets/scan
            // This endpoint requires API key authentication (no CSRF tokens needed)
            struct ScanRequest: Encodable {
                let ticketCode: String

                enum CodingKeys: String, CodingKey {
                    case ticketCode = "ticket_code"
                }
            }

            let scanRequest = ScanRequest(ticketCode: ticketCode)

            // Use raw request so we can handle unexpected shapes while still
            // honoring a successful 2xx response.
            let (rawData, rawResponse) = try await httpClient.requestRaw(
                "/api/tickets/scan",
                method: .post,
                query: nil,
                body: scanRequest,
                instance: instance,
                additionalHeaders: nil
            )

            // If server returned 2xx, attempt to decode permissively; if decoding
            // fails, attempt JSONSerialization-based extraction as a fallback and
            // treat 2xx as a successful scan (server already recorded the scan).
            if (200..<300).contains(rawResponse.statusCode) {
                // Try structured decode first
                let localDecoder = JSONDecoder()
                localDecoder.keyDecodingStrategy = .convertFromSnakeCase
                localDecoder.dateDecodingStrategy = .iso8601
                if let scanResponse = try? localDecoder.decode(ScanResponse.self, from: rawData) {
                    let data = scanResponse.data
                    let ticketIdStr = String(data.sale_id)
                    let holderName = data.sale.name
                    let eventIdStr = String(data.sale.event_id)
                    let eventName = data.sale.event?.name
                    let checkedInAtDate = ISO8601DateFormatter().date(from: data.scanned_at)
                    let messageStr = "✓ \(holderName) - Ticket scanned successfully"
                    return ScanResult(
                        status: .admitted,
                        ticketId: ticketIdStr,
                        holder: holderName,
                        eventId: eventIdStr,
                        eventName: eventName,
                        checkedInAt: checkedInAtDate,
                        gateId: gateId,
                        serverTime: Date(),
                        message: messageStr,
                        saleTicketId: resolvedSaleTicketId
                    )
                }

                // Fallback: parse with JSONSerialization to extract minimal fields
                if let json = try? JSONSerialization.jsonObject(with: rawData, options: []) as? [String: Any],
                   let dataDict = json["data"] as? [String: Any],
                   let sale = dataDict["sale"] as? [String: Any]
                {
                    let holderName = sale["name"] as? String
                    let saleId = sale["id"] as? Int ?? (dataDict["sale_id"] as? Int ?? resolvedSaleTicketId)
                    let scannedAt = dataDict["scanned_at"] as? String
                    let eventDict = sale["event"] as? [String: Any]
                    let eventName = eventDict?["name"] as? String
                    let eventIdStr = (sale["event_id"] as? Int).map { String($0) } ?? (eventDict?["id"] as? String)

                    let checkedInAtDate = scannedAt.flatMap { ISO8601DateFormatter().date(from: $0) }
                    let messageStr = holderName.map { "✓ \($0) - Ticket scanned successfully" } ?? "✓ Ticket scanned successfully"

                    // Attempt to resolve sale_ticket_id via search (best-effort)
                    Task {
                        do {
                            let ticketRepository = RemoteTicketRepository(httpClient: httpClient)
                            let (sales, _) = try await ticketRepository.searchPage(eventId: nil, query: ticketCode, page: 1, perPage: 1, instance: instance)
                            if let saleObj = sales.first {
                                resolvedSaleTicketId = saleObj.tickets.first?.id
                            }
                        } catch {
                            // ignore
                        }
                    }

                    return ScanResult(
                        status: .admitted,
                        ticketId: saleId.map { String($0) } ?? nil,
                        holder: holderName,
                        eventId: eventIdStr,
                        eventName: eventName,
                        checkedInAt: checkedInAtDate,
                        gateId: gateId,
                        serverTime: Date(),
                        message: messageStr,
                        saleTicketId: resolvedSaleTicketId
                    )
                }

                // If we reach here, decoding & extraction both failed but server returned 2xx.
                // Treat as success (server has recorded scan) but return a generic success result.
                // Try to resolve sale_ticket_id in background to help UX.
                Task {
                    do {
                        let ticketRepository = RemoteTicketRepository(httpClient: httpClient)
                        let (sales, _) = try await ticketRepository.searchPage(eventId: nil, query: ticketCode, page: 1, perPage: 1, instance: instance)
                        if let sale = sales.first {
                            resolvedSaleTicketId = sale.tickets.first?.id
                        }
                    } catch { }
                }

                return ScanResult(status: .admitted, message: "Ticket scanned (server confirmed).", saleTicketId: resolvedSaleTicketId)
            }

            // If we somehow received a non-2xx response without an error, surface it as a server error
            throw APIError.serverError(statusCode: rawResponse.statusCode, message: String(data: rawData, encoding: .utf8))
        } catch let apiError as APIError {
            // Map common errors to user-friendly scan results
            switch apiError {
            case .serverError(let status, let message):
                let text = message ?? "Ticket scan failed"
                
                // 404: Ticket not found
                if status == 404 || text.localizedCaseInsensitiveContains("Ticket not found") {
                    return ScanResult(status: .invalid, message: "Ticket not found", saleTicketId: resolvedSaleTicketId)
                }
                
                // 403: Not authorized
                if status == 403 {
                    return ScanResult(status: .invalid, message: "You are not authorized to scan this ticket", saleTicketId: resolvedSaleTicketId)
                }
                
                // 400: Validation errors (date, payment status)
                if status == 400 {
                    if text.localizedCaseInsensitiveContains("not valid for today") {
                        return ScanResult(status: .wrongDate, message: "This ticket is not valid for today", saleTicketId: resolvedSaleTicketId)
                    }
                    if text.localizedCaseInsensitiveContains("not paid") {
                        return ScanResult(status: .unpaid, message: "This ticket is not paid", saleTicketId: resolvedSaleTicketId)
                    }
                    if text.localizedCaseInsensitiveContains("cancelled") {
                        return ScanResult(status: .cancelled, message: "This ticket is cancelled", saleTicketId: resolvedSaleTicketId)
                    }
                    if text.localizedCaseInsensitiveContains("refunded") {
                        return ScanResult(status: .refunded, message: "This ticket is refunded", saleTicketId: resolvedSaleTicketId)
                    }
                            // Other 400 validation errors
                    return ScanResult(status: .invalid, message: text, saleTicketId: resolvedSaleTicketId)
                }
                
                return ScanResult(status: .unknown, message: text, saleTicketId: resolvedSaleTicketId)
            case .unauthorized:
                return ScanResult(status: .invalid, message: "Unauthorized. Check API key.", saleTicketId: resolvedSaleTicketId)
            case .forbidden:
                return ScanResult(status: .invalid, message: "Forbidden. Missing permissions.", saleTicketId: resolvedSaleTicketId)
            case .decodingError:
                // Avoid showing raw server response in UI; log details and return a generic message.
                DebugLogger.error("Scan failed due to decoding error: \(apiError)")
                return ScanResult(status: .invalid, message: "Invalid server response", saleTicketId: resolvedSaleTicketId)
            default:
                return ScanResult(status: .unknown, message: apiError.errorDescription, saleTicketId: resolvedSaleTicketId)
            }
        }
    }

    private static func normalizeEventId(_ raw: String) -> Int? {
        // Backend expects an integer. Try direct Int, then base64-decoded Int.
        if let direct = Int(raw) { return direct }
        if let decoded = Data(base64Encoded: raw), let decodedString = String(data: decoded, encoding: .utf8), let decodedInt = Int(decodedString) {
            return decodedInt
        }
        return nil
    }
}

