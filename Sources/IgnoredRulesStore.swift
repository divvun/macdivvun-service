import Foundation
import OSLog

// Shared between MacDivvun.service and MacDivvunPreferences.app.
enum PreferencesIPC {
    static let suiteName = "no.divvun.MacDivvun"
    static let ignoredRulesKey = "ignoredRules"  // [String: [String]] — locale → sorted rule ids
    static let darwinNotification = "no.divvun.MacDivvun.preferencesChanged"
}

struct IgnoredRulesStore {
    private let defaults: UserDefaults

    init(suiteName: String = PreferencesIPC.suiteName) {
        self.defaults = UserDefaults(suiteName: suiteName) ?? .standard
    }

    func load() -> [String: Set<String>] {
        guard let raw = defaults.dictionary(forKey: PreferencesIPC.ignoredRulesKey) else { return [:] }
        var out: [String: Set<String>] = [:]
        for (locale, value) in raw {
            if let arr = value as? [String] {
                out[locale] = Set(arr)
            }
        }
        return out
    }

    func ignored(for locale: String) -> Set<String> {
        load()[locale] ?? []
    }

    func setIgnored(_ ignored: Set<String>, for locale: String) {
        var current = (defaults.dictionary(forKey: PreferencesIPC.ignoredRulesKey) as? [String: [String]]) ?? [:]
        if ignored.isEmpty {
            current.removeValue(forKey: locale)
        } else {
            current[locale] = Array(ignored).sorted()
        }
        defaults.set(current, forKey: PreferencesIPC.ignoredRulesKey)
        postChangeNotification()
    }

    func postChangeNotification() {
        let name = CFNotificationName(PreferencesIPC.darwinNotification as CFString)
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            name, nil, nil, true
        )
    }
}

// Observer side: subscribes to the Darwin notification and invokes a callback.
final class IgnoredRulesObserver {
    private var token: CFNotificationName?
    private let onChange: () -> Void

    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
    }

    func start() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let observer = Unmanaged.passUnretained(self).toOpaque()
        let name = CFNotificationName(PreferencesIPC.darwinNotification as CFString)
        CFNotificationCenterAddObserver(
            center, observer,
            { _, observer, _, _, _ in
                guard let observer = observer else { return }
                let me = Unmanaged<IgnoredRulesObserver>.fromOpaque(observer).takeUnretainedValue()
                me.onChange()
            },
            name.rawValue, nil, .deliverImmediately
        )
        token = name
    }

    deinit {
        guard token != nil else { return }
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterRemoveEveryObserver(center, observer)
    }
}
