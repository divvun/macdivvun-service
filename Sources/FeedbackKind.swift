import Foundation

enum FeedbackKind: String, Sendable {
    case suggestion
    case missingWord = "missing-word"
}

struct FeedbackPrefill: Sendable {
    var kind: FeedbackKind
    var word: String?
    var paragraph: String?
    var locale: String?
    var appBundleID: String?

    enum MarkKind: String, Sendable {
        case spelling
        case grammar
    }
    var markKind: MarkKind?
}

enum FeedbackURL {
    static let scheme = "macdivvun"
    static let host = "feedback"

    static func build(_ prefill: FeedbackPrefill) -> URL {
        var c = URLComponents()
        c.scheme = scheme
        c.host = host
        c.path = "/" + prefill.kind.rawValue
        var items: [URLQueryItem] = []
        if let word = prefill.word { items.append(URLQueryItem(name: "word", value: word)) }
        if let paragraph = prefill.paragraph { items.append(URLQueryItem(name: "context", value: paragraph)) }
        if let locale = prefill.locale { items.append(URLQueryItem(name: "locale", value: locale)) }
        if let bundleID = prefill.appBundleID { items.append(URLQueryItem(name: "app", value: bundleID)) }
        if let markKind = prefill.markKind { items.append(URLQueryItem(name: "mark", value: markKind.rawValue)) }
        if !items.isEmpty { c.queryItems = items }
        return c.url!
    }

    static func parse(_ url: URL) -> FeedbackPrefill? {
        guard url.scheme == scheme, url.host == host else { return nil }
        let pathRaw = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let kind = FeedbackKind(rawValue: pathRaw) else { return nil }
        var prefill = FeedbackPrefill(kind: kind)
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        for item in items {
            switch item.name {
            case "word": prefill.word = item.value
            case "context": prefill.paragraph = item.value
            case "locale": prefill.locale = item.value
            case "app": prefill.appBundleID = item.value
            case "mark": prefill.markKind = item.value.flatMap(FeedbackPrefill.MarkKind.init(rawValue:))
            default: break
            }
        }
        return prefill
    }
}
