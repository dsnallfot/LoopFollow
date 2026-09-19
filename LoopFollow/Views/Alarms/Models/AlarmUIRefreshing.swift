import Foundation

/// Protocol used by external callers (SnoozeViewController, SAge, Alarms, intents, etc.)
/// to trigger a UI refresh of alarm-related state (snooze/mute) without knowing about
/// the underlying view implementation.
protocol AlarmUIRefreshing: AnyObject {
    // Legacy API utan value-parameter (många call sites använder denna)
    func reloadSnoozeTime(key: String, setNil: Bool)
    func reloadMuteTime(key: String, setNil: Bool)

    // API där ett specifikt datum skickas med (SnoozeViewController, intents m.m.)
    func reloadSnoozeTime(key: String, setNil: Bool, value: Date)
    func reloadMuteTime(key: String, setNil: Bool, value: Date)

    func reloadIsSnoozed(key: String, value: Bool)
    func reloadIsMuted(key: String, value: Bool)
}
