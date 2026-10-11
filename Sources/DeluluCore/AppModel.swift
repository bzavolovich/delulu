import Combine
import Foundation

public enum NotificationPermission: Sendable { case notRequested, allowed, denied, unavailable }

@MainActor public protocol NotificationScheduling {
    func permission() async -> NotificationPermission
    func requestPermission() async throws -> Bool
    func schedule(_ schedule: RecurringSchedule) async throws
    func sendNow(_ message: RecruiterMessage, sound: Bool) async throws
    func cancelRecurring()
    func preparePendingRequests() async throws
    func hasRecurringRequest() async -> Bool
}

@MainActor public final class AppModel: ObservableObject {
    @Published public private(set) var state: AppState
    @Published public private(set) var permission: NotificationPermission = .notRequested
    @Published public private(set) var isSending = false
    @Published public var error: String?
    @Published public private(set) var storageBlocked = false
    private let store: any StatePersisting
    private let notifications: any NotificationScheduling

    public init(store: any StatePersisting, notifications: any NotificationScheduling) {
        self.store = store
        self.notifications = notifications
        var loaded = AppState()
        var loadError: String?
        do { loaded = try store.load() }
        catch { loadError = "Couldn't read saved settings. \(error.localizedDescription)" }
        state = loaded
        error = loadError
        storageBlocked = loadError != nil
    }

    public func refresh() async { permission = await notifications.permission() }

    public func restoreSchedule() async {
        guard !isSending, !storageBlocked else { return }
        isSending = true
        defer { isSending = false }
        // One-off notifications from the old UI no longer have a cancellation screen.
        do { try await notifications.preparePendingRequests() }
        catch {
            self.error = "Couldn't refresh notification settings. \(error.localizedDescription)"
            return
        }
        await refresh()
        if state.schedule != nil {
            if !(await notifications.hasRecurringRequest()) {
                // A missing OS request may be a stop whose disk write failed.
                // Never silently re-enable it from stale persisted state.
                var next = state
                next.schedule = nil
                _ = persist(next)
            }
        } else {
            notifications.cancelRecurring()
        }
    }

    @discardableResult public func apply(mode: MessageMode, cadence: DeliveryCadence, sound: Bool) async -> Bool {
        guard !isSending, !storageBlocked else { return false }
        if let validation = state.profile.validationError { error = validation; return false }
        isSending = true
        defer { isSending = false }
        error = nil
        guard await authorize() else { return false }
        var next = state
        next.mode = mode
        next.cadence = cadence
        next.soundEnabled = sound
        next.schedule = makeSchedule(for: next)
        return await commitSchedule(next)
    }

    @discardableResult public func saveProfile(_ profile: DreamProfile) async -> Bool {
        guard !isSending, !storageBlocked else { return false }
        if let validation = profile.validationError { error = validation; return false }
        error = nil
        var next = state
        next.profile = profile.normalized
        guard state.schedule != nil else { return persist(next) }
        isSending = true
        defer { isSending = false }
        guard await authorize() else { return false }
        next.schedule = makeSchedule(for: next)
        return await commitSchedule(next)
    }

    private func makeSchedule(for state: AppState) -> RecurringSchedule {
        RecurringSchedule(message: MessageGenerator.generate(profile: state.profile, mode: state.mode,
                                                              variant: Int.random(in: 0..<MessageGenerator.variantCount)),
                          cadence: state.cadence, soundEnabled: state.soundEnabled)
    }

    @discardableResult public func sendNow(mode: MessageMode, sound: Bool) async -> Bool {
        guard !isSending, !storageBlocked else { return false }
        if let validation = state.profile.validationError { error = validation; return false }
        isSending = true
        defer { isSending = false }
        error = nil
        guard await authorize() else { return false }
        let message = MessageGenerator.generate(profile: state.profile, mode: mode,
                                                variant: Int.random(in: 0..<MessageGenerator.variantCount))
        do {
            try await notifications.sendNow(message, sound: sound)
            return true
        } catch {
            self.error = "Couldn't send the notification. \(error.localizedDescription)"
            return false
        }
    }

    public func stop() {
        guard !isSending else { return }
        notifications.cancelRecurring()
        var next = state
        next.schedule = nil
        if !persist(next) {
            state.schedule = nil
            storageBlocked = true
            error = "Notifications stopped, but settings couldn't be saved. Free disk space and retry after restarting."
        } else { error = nil }
    }

    private func authorize() async -> Bool {
        do {
            permission = await notifications.permission()
            if permission == .notRequested {
                permission = try await notifications.requestPermission() ? .allowed : .denied
            }
            guard permission == .allowed else {
                error = permission == .unavailable ? "Open the packaged Delulu.app to enable notifications."
                    : "Allow Delulu in System Settings → Notifications."
                return false
            }
            return true
        } catch { self.error = "Couldn't enable notifications. \(error.localizedDescription)"; return false }
    }

    private func commitSchedule(_ next: AppState) async -> Bool {
        guard let schedule = next.schedule else { return false }
        let previous = state
        guard persist(next) else { return false }
        do {
            // One stable identifier replaces the previous recurring request.
            try await notifications.schedule(schedule)
            return true
        } catch {
            if persist(previous) { self.error = "Couldn't update notifications. \(error.localizedDescription)" }
            else { storageBlocked = true }
            return false
        }
    }

    @discardableResult private func persist(_ next: AppState) -> Bool {
        guard !storageBlocked else { return false }
        do { try store.save(next); state = next; return true }
        catch { self.error = "Couldn't save settings. \(error.localizedDescription)"; return false }
    }
}
