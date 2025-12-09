//
//  EventScheduleTests.swift
//  EventScheduleTests
//
//  Created by David Fiore on 12/8/25.
//

import Testing
@testable import EventSchedule

struct EventScheduleTests {

    @Test func eventDateRoundTripPreservesInstant() async throws {
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

        #expect(event.startAt == isoFormatter.date(from: startString))
        #expect(event.endAt == isoFormatter.date(from: endString))

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let encoded = try encoder.encode(event)

        let encodedJSON = try (JSONSerialization.jsonObject(with: encoded) as? [String: Any]).unwrap()
        let encodedStart = try (encodedJSON["starts_at"] as? String).unwrap()
        let encodedEnd = try (encodedJSON["ends_at"] as? String).unwrap()

        #expect(encodedStart == startString)
        #expect(encodedEnd == endString)

        #expect(isoFormatter.date(from: encodedStart) == event.startAt)
        #expect(isoFormatter.date(from: encodedEnd) == event.endAt)
    }

}
