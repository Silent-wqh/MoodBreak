import Foundation

final class Storage {
    private let defaults: UserDefaults
    private let muteUntilKey = "mute_until"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadMuteUntil() -> Date? {
        defaults.object(forKey: muteUntilKey) as? Date
    }

    func saveMuteUntil(_ date: Date?) {
        if let date {
            defaults.set(date, forKey: muteUntilKey)
        } else {
            defaults.removeObject(forKey: muteUntilKey)
        }
    }
}
