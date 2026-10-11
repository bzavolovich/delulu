import Foundation

public struct AppState: Codable, Equatable, Sendable {
    public var profile: DreamProfile
    public var mode: MessageMode
    public var cadence: DeliveryCadence
    public var soundEnabled: Bool
    public var schedule: RecurringSchedule?

    public init(profile: DreamProfile = DreamProfile(), mode: MessageMode = .outreach,
                cadence: DeliveryCadence = .fifteenMinutes, soundEnabled: Bool = true,
                schedule: RecurringSchedule? = nil) {
        self.profile = profile
        self.mode = mode
        self.cadence = cadence
        self.soundEnabled = soundEnabled
        self.schedule = schedule
    }

    private enum CodingKeys: String, CodingKey { case profile, mode, cadence, soundEnabled, schedule }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        profile = try values.decode(DreamProfile.self, forKey: .profile)
        mode = try values.decode(MessageMode.self, forKey: .mode)
        soundEnabled = try values.decode(Bool.self, forKey: .soundEnabled)
        // Existing profiles migrate without retaining the removed inbox or company field.
        cadence = try values.decodeIfPresent(DeliveryCadence.self, forKey: .cadence) ?? .fifteenMinutes
        schedule = try values.decodeIfPresent(RecurringSchedule.self, forKey: .schedule)
    }
}

@MainActor public protocol StatePersisting {
    func load() throws -> AppState
    func save(_ state: AppState) throws
}

@MainActor public final class FileStateStore: StatePersisting {
    public let url: URL
    public init(url: URL) { self.url = url }

    public static var defaultURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Delulu", isDirectory: true).appendingPathComponent("state.json")
    }

    public func load() throws -> AppState {
        guard FileManager.default.fileExists(atPath: url.path) else { return AppState() }
        return try JSONDecoder().decode(AppState.self, from: Data(contentsOf: url))
    }

    public func save(_ state: AppState) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                               attributes: [.posixPermissions: 0o700])
        let data = try JSONEncoder().encode(state)
        try data.write(to: url, options: [.atomic])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
