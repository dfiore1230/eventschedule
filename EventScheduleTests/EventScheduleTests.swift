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

    @Test func dstPayloadsRemainUTC() async throws {
        let pacific = try TimeZone(identifier: "America/Los_Angeles").unwrap()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = pacific

        let startComponents = DateComponents(year: 2024, month: 3, day: 10, hour: 1, minute: 30)
        let endComponents = DateComponents(year: 2024, month: 3, day: 10, hour: 3, minute: 30)

        let start = try calendar.date(from: startComponents).unwrap()
        let end = try calendar.date(from: endComponents).unwrap()

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
            status: .scheduled,
            images: [],
            capacity: nil,
            ticketTypes: [],
            publishState: .draft,
            timezone: pacific.identifier,
            curatorId: nil,
            talentIds: [],
            category: nil,
            groupSlug: nil,
            onlineURL: nil
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let encoded = try encoder.encode(event)

        let encodedJSON = try (JSONSerialization.jsonObject(with: encoded) as? [String: Any]).unwrap()
        let encodedStart = try (encodedJSON["starts_at"] as? String).unwrap()
        let encodedEnd = try (encodedJSON["ends_at"] as? String).unwrap()

        #expect(encodedStart == "2024-03-10 01:30:00")
        #expect(encodedEnd == "2024-03-10 03:30:00")
    }

    @Test func displayFormattersRespectSelectedTimeZone() async throws {
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = DateFormatterFactory.utcTimeZone
        let utcDate = try utcCalendar.date(from: DateComponents(year: 2024, month: 12, day: 15, hour: 15, minute: 0)).unwrap()

        let payloadString = Event.payloadDateFormatter().string(from: utcDate)
        #expect(payloadString == "2024-12-15 15:00:00")

        let posixLocale = Locale(identifier: "en_US_POSIX")
        let tokyo = try TimeZone(identifier: "Asia/Tokyo").unwrap()
        let newYork = try TimeZone(identifier: "America/New_York").unwrap()

        let tokyoDisplay = DateFormatterFactory.displayFormatter(timeZone: tokyo, locale: posixLocale).string(from: utcDate)
        let newYorkDisplay = DateFormatterFactory.displayFormatter(timeZone: newYork, locale: posixLocale).string(from: utcDate)

        #expect(tokyoDisplay == "Dec 16, 2024 at 12:00 AM")
        #expect(newYorkDisplay == "Dec 15, 2024 at 10:00 AM")
        #expect(tokyoDisplay != newYorkDisplay)
    }

}
