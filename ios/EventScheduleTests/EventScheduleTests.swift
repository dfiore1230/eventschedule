//
//  EventScheduleTests.swift
//  EventScheduleTests
//
//  Created by David Fiore on 12/8/25.
//

import Testing
import Foundation
@testable import EventSchedule

struct EventScheduleTests {

    @Test @MainActor func eventDateRoundTripPreservesInstant() async throws {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        isoFormatter.timeZone = TimeZone(secondsFromGMT: 0)

        let startString = "2024-06-10T10:00:00Z"
        let endString = "2024-06-10T11:00:00Z"

        let json = """
        {
            "id": "evt-1",
            "name": "Sample Event",
            "description": "",
            "starts_at": "\(startString)",
            "ends_at": "\(endString)",
            "venue_id": "venue-1",
            "status": "scheduled",
            "images": [],
            "ticket_types": [],
            "publish_state": "draft",
            "talent_ids": []
        }
        """

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        let event = try decoder.decode(Event.self, from: Data(json.utf8))

        if event.startAt != isoFormatter.date(from: startString) {
            throw NSError(domain: "EventScheduleTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "startAt mismatch: expected \(isoFormatter.string(from: isoFormatter.date(from: startString)!)), got \(isoFormatter.string(from: event.startAt))"]) 
        }
        if event.endAt != isoFormatter.date(from: endString) {
            throw NSError(domain: "EventScheduleTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "endAt mismatch: expected \(isoFormatter.string(from: isoFormatter.date(from: endString)!)), got \(isoFormatter.string(from: event.endAt))"]) 
        }

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let encoded = try encoder.encode(event)

        guard let encodedJSON = try JSONSerialization.jsonObject(with: encoded) as? [String: Any] else {
            throw NSError(domain: "EventScheduleTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Encoded JSON missing"]) 
        }
        // Accept either 'starts_at' or 'start_at' to be permissive
        let encodedStart = (encodedJSON["starts_at"] as? String) ?? (encodedJSON["start_at"] as? String)
        let encodedEnd = (encodedJSON["ends_at"] as? String) ?? (encodedJSON["end_at"] as? String)
        if encodedStart == nil || encodedEnd == nil {
            throw NSError(domain: "EventScheduleTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Encoded start/end missing"]) 
        }

        // The Event encoder uses the payload formatter which produces 'yyyy-MM-dd HH:mm:ss' strings.
        let payloadFormatter = Event.payloadDateFormatter()
        if encodedStart != payloadFormatter.string(from: event.startAt) {
            throw NSError(domain: "EventScheduleTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "encodedStart mismatch: expected \(payloadFormatter.string(from: event.startAt)), got \(String(describing: encodedStart))"]) 
        }
        if encodedEnd != payloadFormatter.string(from: event.endAt) {
            throw NSError(domain: "EventScheduleTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "encodedEnd mismatch: expected \(payloadFormatter.string(from: event.endAt)), got \(String(describing: encodedEnd))"]) 
        }

        if payloadFormatter.date(from: encodedStart!) != event.startAt {
            throw NSError(domain: "EventScheduleTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "payload formatter date from encodedStart not equal to event.startAt"]) 
        }
        if payloadFormatter.date(from: encodedEnd!) != event.endAt {
            throw NSError(domain: "EventScheduleTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "payload formatter date from encodedEnd not equal to event.endAt"]) 
        }
    }

    @Test @MainActor func dstPayloadsRemainUTC() async throws {
        guard let pacific = TimeZone(identifier: "America/Los_Angeles") else {
            throw NSError(domain: "EventScheduleTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing time zone"]) 
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = pacific

        let startComponents = DateComponents(year: 2024, month: 3, day: 10, hour: 1, minute: 30)
        let endComponents = DateComponents(year: 2024, month: 3, day: 10, hour: 3, minute: 30)

        guard let start = calendar.date(from: startComponents), let end = calendar.date(from: endComponents) else {
            throw NSError(domain: "EventScheduleTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to construct test dates"]) 
        }

        let event = Event(
            id: "dst-event",
            name: "DST Sample",
            description: nil,
            startAt: start,
            endAt: end,
            durationMinutes: 120,
            venueId: "venue-1",
            venueName: nil,
            roomId: nil,
            images: [],
            capacity: nil,
            ticketTypes: [],
            publishState: .draft,
            curatorId: nil,
            talentIds: [],
            category: nil,
            groupSlug: nil,
            onlineURL: nil,
            timezone: pacific.identifier
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let encoded = try encoder.encode(event)

        guard let encodedJSON = try JSONSerialization.jsonObject(with: encoded) as? [String: Any] else {
            throw NSError(domain: "EventScheduleTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Encoded JSON missing"]) 
        }
        // Accept either 'starts_at' or 'start_at' to be permissive
        let encodedStart = (encodedJSON["starts_at"] as? String) ?? (encodedJSON["start_at"] as? String)
        let encodedEnd = (encodedJSON["ends_at"] as? String) ?? (encodedJSON["end_at"] as? String)
        if encodedStart == nil || encodedEnd == nil {
            throw NSError(domain: "EventScheduleTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Encoded start/end missing"]) 
        }

        if encodedStart != "2024-03-10 01:30:00" {
            throw NSError(domain: "EventScheduleTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "encodedStart mismatch: expected 2024-03-10 01:30:00, got \(encodedStart)"])
        }
        if encodedEnd != "2024-03-10 03:30:00" {
            throw NSError(domain: "EventScheduleTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "encodedEnd mismatch: expected 2024-03-10 03:30:00, got \(encodedEnd)"])
        }
    }

    @Test @MainActor func displayFormattersRespectSelectedTimeZone() async throws {
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = DateFormatterFactory.utcTimeZone
        guard let utcDate = utcCalendar.date(from: DateComponents(year: 2024, month: 12, day: 15, hour: 15, minute: 0)) else {
            throw NSError(domain: "EventScheduleTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create UTC date"]) 
        }

        let payloadString = Event.payloadDateFormatter().string(from: utcDate)
        if payloadString != "2024-12-15 15:00:00" {
            throw NSError(domain: "EventScheduleTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "payloadString mismatch: expected 2024-12-15 15:00:00, got \(payloadString)"])
        }

        let posixLocale = Locale(identifier: "en_US_POSIX")
        guard let tokyo = TimeZone(identifier: "Asia/Tokyo"), let newYork = TimeZone(identifier: "America/New_York") else {
            throw NSError(domain: "EventScheduleTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing test time zones"]) 
        }
        let tokyoDisplay = DateFormatterFactory.displayFormatter(timeZone: tokyo, locale: posixLocale).string(from: utcDate)
        let newYorkDisplay = DateFormatterFactory.displayFormatter(timeZone: newYork, locale: posixLocale).string(from: utcDate)

        let normalizeSpaces: (String) -> String = { s in
            s.replacingOccurrences(of: "\u{202F}", with: " ")
             .replacingOccurrences(of: "\u{00A0}", with: " ")
        }

        if normalizeSpaces(tokyoDisplay) != "Dec 16, 2024 at 12:00 AM" {
            throw NSError(domain: "EventScheduleTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "tokyoDisplay mismatch: expected Dec 16, 2024 at 12:00 AM, got \(tokyoDisplay)"])
        }
        if normalizeSpaces(newYorkDisplay) != "Dec 15, 2024 at 10:00 AM" {
            throw NSError(domain: "EventScheduleTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "newYorkDisplay mismatch: expected Dec 15, 2024 at 10:00 AM, got \(newYorkDisplay)"])
        }
        if normalizeSpaces(tokyoDisplay) == normalizeSpaces(newYorkDisplay) {
            throw NSError(domain: "EventScheduleTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "tokyoDisplay should not equal newYorkDisplay"])
        }
    }

}
