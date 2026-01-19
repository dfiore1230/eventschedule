import Foundation
import SwiftUI
import Combine

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var timeZoneIdentifier: String {
        didSet { persist() }
    }

    var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? .current
    }

    private let defaults: UserDefaults
    private let timeZoneKey = "app_settings.time_zone_identifier"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let stored = defaults.string(forKey: timeZoneKey), TimeZone(identifier: stored) != nil {
            timeZoneIdentifier = stored
        } else {
            timeZoneIdentifier = TimeZone.current.identifier
        }
    }

    func resetTimeZoneToCurrent() {
        timeZoneIdentifier = TimeZone.current.identifier
    }

    private func persist() {
        defaults.set(timeZoneIdentifier, forKey: timeZoneKey)
    }
}
