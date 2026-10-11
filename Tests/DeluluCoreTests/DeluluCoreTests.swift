import Foundation
import Testing
@testable import DeluluCore

@Test func messagePersonalization() {
    let profile = DreamProfile(name: " Jo\n Smith ", role: "Staff Engineer", strength: "building tools",
                               compensation: "€150,000", location: "Berlin")
    for mode in MessageMode.allCases {
        var bodies = Set<String>()
        for index in 0..<MessageGenerator.variantCount {
            let message = MessageGenerator.generate(profile: profile, mode: mode, variant: index)
            #expect(message.body.contains("Hi Jo Smith,"))
            #expect(message.body.contains("Staff Engineer"))
            #expect(message.body.contains(message.company))
            #expect(message.notificationSubtitle == message.subject)
            #expect(message.body.contains("€150,000") == (mode == .offer))
            bodies.insert(message.body)
        }
        #expect(bodies.count == MessageGenerator.variantCount)
    }
    #expect(DreamProfile(name: "  ").validationError != nil)
    #expect(DreamProfile(role: String(repeating: "a", count: 101)).validationError != nil)
    #expect(DreamProfile(strength: String(repeating: "a", count: 241)).validationError != nil)
}

@Test func recurringIntervals() {
    #expect(DeliveryCadence.allCases.map(\.interval) == [60, 300, 900, 3600, 10800])
}

@Test @MainActor func sendNowUsesSelectedModeWithoutStartingOrChangingSchedule() async {
    let store = MemoryStore()
    let notifications = FakeNotifications()
    let model = AppModel(store: store, notifications: notifications)
    #expect(await model.sendNow(mode: .offer, sound: false))
    #expect(notifications.instantMessages.first?.mode == .offer)
    #expect(notifications.instantSound == false)
    #expect(store.state.schedule == nil)
    #expect(notifications.current == nil)
    #expect(await model.apply(mode: .outreach, cadence: .minute, sound: true))
    let previous = model.state
    #expect(await model.sendNow(mode: .offer, sound: false))
    #expect(model.state == previous)
    #expect(notifications.current == previous.schedule)
    #expect(notifications.scheduleCalls == 1)
    #expect(notifications.instantMessages.count == 2)
    #expect(!model.isSending)
}

@Test @MainActor func sendNowHandlesDenialAndDeliveryFailure() async {
    let notifications = FakeNotifications()
    let model = AppModel(store: MemoryStore(), notifications: notifications)
    notifications.authorization = .denied
    #expect(await !model.sendNow(mode: .offer, sound: true))
    #expect(notifications.instantMessages.isEmpty)
    #expect(model.error != nil)
    notifications.authorization = .allowed
    notifications.failScheduling = true
    #expect(await !model.sendNow(mode: .offer, sound: true))
    #expect(notifications.instantMessages.isEmpty)
    #expect(model.error?.contains("Couldn't send") == true)
    #expect(!model.isSending)
}

@Test @MainActor func legacySettingsMigrateWithoutEnablingNotifications() throws {
    let json = """
    {"profile":{"name":"Jo","company":"Old company","role":"Designer","strength":"","compensation":"","location":"Remote"},
    "mode":"offer","soundEnabled":false,"history":[{"old":"inbox"}]}
    """
    let migrated = try JSONDecoder().decode(AppState.self, from: Data(json.utf8))
    #expect(migrated.profile.name == "Jo")
    #expect(migrated.mode == .offer)
    #expect(migrated.cadence == .fifteenMinutes)
    #expect(!migrated.soundEnabled)
    #expect(migrated.schedule == nil)
    let serialized = String(decoding: try JSONEncoder().encode(migrated), as: UTF8.self)
    #expect(!serialized.contains("Old company"))
    #expect(!serialized.contains("history"))
}

@Test @MainActor func persistenceAndCorruptDataProtection() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("state.json")
    let store = FileStateStore(url: url)
    #expect(try store.load() == AppState())
    let model = AppModel(store: store, notifications: FakeNotifications())
    #expect(await model.apply(mode: .offer, cadence: .threeHours, sound: false))
    #expect(try store.load() == model.state)
    #expect(try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? Int == 0o600)
    let corrupt = Data("broken json".utf8)
    try corrupt.write(to: url)
    let reloaded = AppModel(store: store, notifications: FakeNotifications())
    #expect(reloaded.storageBlocked)
    #expect(await !reloaded.saveProfile(DreamProfile(name: "Someone else")))
    #expect(try Data(contentsOf: url) == corrupt)
}

@Test @MainActor func applyReplacesSingleScheduleAndPersists() async {
    let store = MemoryStore()
    let notifications = FakeNotifications()
    let model = AppModel(store: store, notifications: notifications)
    #expect(await model.apply(mode: .outreach, cadence: .fiveMinutes, sound: true))
    #expect(await model.apply(mode: .offer, cadence: .hour, sound: false))
    #expect(notifications.current?.cadence == .hour)
    #expect(notifications.current?.message.mode == .offer)
    #expect(notifications.current?.soundEnabled == false)
    #expect(store.state == model.state)
    #expect(model.state.schedule == notifications.current)
    #expect(!model.isSending)
}

@Test @MainActor func permissionHandling() async {
    for permission in [NotificationPermission.denied, .unavailable] {
        let notifications = FakeNotifications()
        notifications.authorization = permission
        let model = AppModel(store: MemoryStore(), notifications: notifications)
        #expect(await !model.apply(mode: .offer, cadence: .hour, sound: true))
        #expect(model.state.schedule == nil)
        #expect(notifications.current == nil)
        #expect(model.error != nil)
    }
    let notifications = FakeNotifications()
    notifications.authorization = .notRequested
    let model = AppModel(store: MemoryStore(), notifications: notifications)
    #expect(await model.apply(mode: .offer, cadence: .hour, sound: true))
    #expect(await model.apply(mode: .offer, cadence: .threeHours, sound: true))
    #expect(notifications.permissionRequests == 1)
}

@Test @MainActor func deniedPromptDoesNotStartSchedule() async {
    let notifications = FakeNotifications()
    notifications.authorization = .notRequested
    notifications.grantPermission = false
    let model = AppModel(store: MemoryStore(), notifications: notifications)
    #expect(await !model.apply(mode: .offer, cadence: .hour, sound: true))
    #expect(notifications.current == nil)
    #expect(model.permission == .denied)
}

@Test @MainActor func failedUpdatesPreserveExistingSchedule() async {
    let store = MemoryStore()
    let notifications = FakeNotifications()
    let model = AppModel(store: store, notifications: notifications)
    #expect(await model.apply(mode: .outreach, cadence: .fiveMinutes, sound: true))
    let previous = model.state
    notifications.failScheduling = true
    #expect(await !model.apply(mode: .offer, cadence: .hour, sound: false))
    #expect(model.state == previous)
    #expect(store.state == previous)
    #expect(notifications.current == previous.schedule)
    notifications.failScheduling = false
    store.failSaving = true
    #expect(await !model.apply(mode: .offer, cadence: .hour, sound: false))
    #expect(notifications.current == previous.schedule)
}

@Test @MainActor func stopAndRestoreDoNotDuplicateRequests() async {
    let store = MemoryStore()
    let notifications = FakeNotifications()
    let model = AppModel(store: store, notifications: notifications)
    #expect(await model.apply(mode: .outreach, cadence: .fiveMinutes, sound: true))
    let reloaded = AppModel(store: store, notifications: notifications)
    await reloaded.restoreSchedule()
    #expect(notifications.scheduleCalls == 1)
    #expect(notifications.removedLegacy)
    notifications.current = nil
    await reloaded.restoreSchedule()
    #expect(notifications.scheduleCalls == 1)
    #expect(reloaded.state.schedule == nil)
    #expect(await reloaded.apply(mode: .offer, cadence: .hour, sound: false))
    reloaded.stop()
    #expect(store.state.schedule == nil)
    #expect(notifications.current == nil)
    await reloaded.restoreSchedule()
    #expect(notifications.scheduleCalls == 2)
}

@Test @MainActor func profileUpdatesOnlyRescheduleWhenActive() async {
    let notifications = FakeNotifications()
    let model = AppModel(store: MemoryStore(), notifications: notifications)
    #expect(await model.saveProfile(DreamProfile(name: "Jo")))
    #expect(notifications.scheduleCalls == 0)
    #expect(await model.apply(mode: .offer, cadence: .hour, sound: true))
    #expect(await model.saveProfile(DreamProfile(name: "Pat", role: "Engineer")))
    #expect(notifications.current?.message.body.contains("Hi Pat,") == true)
    #expect(notifications.current?.message.body.contains("Engineer") == true)
    #expect(notifications.current?.cadence == .hour)
}

@Test @MainActor func stopCancelsEvenWhenDiskFails() async {
    let store = MemoryStore()
    let notifications = FakeNotifications()
    let model = AppModel(store: store, notifications: notifications)
    #expect(await model.apply(mode: .offer, cadence: .hour, sound: true))
    store.failSaving = true
    model.stop()
    #expect(notifications.current == nil)
    #expect(model.state.schedule == nil)
    #expect(model.error != nil)
    #expect(model.storageBlocked)
}

@MainActor private final class MemoryStore: StatePersisting {
    var state = AppState()
    var failSaving = false
    func load() throws -> AppState { state }
    func save(_ state: AppState) throws {
        if failSaving { throw CocoaError(.fileWriteNoPermission) }
        self.state = state
    }
}

@MainActor private final class FakeNotifications: NotificationScheduling {
    var authorization: NotificationPermission = .allowed
    var grantPermission = true
    var permissionRequests = 0
    var current: RecurringSchedule?
    var scheduleCalls = 0
    var failScheduling = false
    var removedLegacy = false
    var instantMessages: [RecruiterMessage] = []
    var instantSound = true
    func permission() async -> NotificationPermission { authorization }
    func requestPermission() async throws -> Bool {
        permissionRequests += 1
        authorization = grantPermission ? .allowed : .denied
        return grantPermission
    }
    func schedule(_ schedule: RecurringSchedule) async throws {
        if failScheduling { throw CocoaError(.featureUnsupported) }
        scheduleCalls += 1
        current = schedule
    }
    func cancelRecurring() { current = nil }
    func sendNow(_ message: RecruiterMessage, sound: Bool) async throws {
        if failScheduling { throw CocoaError(.featureUnsupported) }
        instantMessages.append(message)
        instantSound = sound
    }
    func preparePendingRequests() async throws { removedLegacy = true }
    func hasRecurringRequest() async -> Bool { current != nil }
}
