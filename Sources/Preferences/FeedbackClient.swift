import Foundation
import OSLog

struct FeedbackPayload: Encodable, Sendable {
    let kind: String
    let locale: String?
    let word: String?
    let paragraph: String?
    let comment: String?
    let appBundleID: String?
    let appVersion: String
    let osVersion: String
    let timestamp: String
    let markKind: String?
}

enum FeedbackClient {
    static let endpointInfoKey = "MacDivvunFeedbackEndpoint"
    private static let placeholderHost = "feedback.divvun.no"
    private static let log = Logger(subsystem: "no.divvun.MacDivvunPreferences", category: "feedback")

    static func submit(_ payload: FeedbackPayload) async throws {
        let data = try JSONEncoder().encode(payload)
        guard let endpoint = endpointURL() else {
            log.notice("No feedback endpoint configured; payload logged only: \(String(decoding: data, as: UTF8.self), privacy: .public)")
            return
        }

        if endpoint.host == placeholderHost {
            log.notice("Feedback endpoint still pointing at placeholder; not POSTing. payload=\(String(decoding: data, as: UTF8.self), privacy: .public)")
            return
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "MacDivvunFeedback", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Feedback endpoint returned a non-success status"
            ])
        }
    }

    static func endpointURL() -> URL? {
        guard let raw = Foundation.Bundle.main.object(forInfoDictionaryKey: endpointInfoKey) as? String,
              !raw.isEmpty,
              let url = URL(string: raw) else { return nil }
        return url
    }

    static func makePayload(prefill: FeedbackPrefill, comment: String?) -> FeedbackPayload {
        let bundle = Foundation.Bundle.main
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let pinfo = ProcessInfo.processInfo.operatingSystemVersion
        let os = "\(pinfo.majorVersion).\(pinfo.minorVersion).\(pinfo.patchVersion)"
        let timestamp = ISO8601DateFormatter().string(from: Date())
        return FeedbackPayload(
            kind: prefill.kind.rawValue,
            locale: prefill.locale,
            word: prefill.word,
            paragraph: prefill.paragraph,
            comment: comment,
            appBundleID: prefill.appBundleID,
            appVersion: version,
            osVersion: os,
            timestamp: timestamp,
            markKind: prefill.markKind?.rawValue
        )
    }
}
