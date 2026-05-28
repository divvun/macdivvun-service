import SwiftUI

@main
struct MacDivvunPreferencesApp: App {
    @State private var feedbackPrefill: FeedbackPrefill?

    var body: some Scene {
        WindowGroup("MacDivvun Preferences") {
            ContentView()
                .frame(minWidth: 540, minHeight: 480)
                .sheet(item: $feedbackPrefill) { prefill in
                    FeedbackSheet(prefill: prefill) {
                        feedbackPrefill = nil
                    }
                }
                .onOpenURL { url in
                    if url.scheme == FeedbackURL.scheme, let parsed = FeedbackURL.parse(url) {
                        feedbackPrefill = parsed
                    }
                }
        }
        .commands {
            CommandGroup(replacing: .help) {
                Button("Report a Suggestion…") {
                    feedbackPrefill = FeedbackPrefill(kind: .suggestion)
                }
                Button("Suggest a Missing Word…") {
                    feedbackPrefill = FeedbackPrefill(kind: .missingWord)
                }
                Divider()
                Button("MacDivvun on GitHub") {
                    if let url = URL(string: "https://github.com/divvun/macdivvun-service") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }
}

extension FeedbackPrefill: Identifiable {
    public var id: String {
        "\(kind.rawValue)|\(word ?? "")|\(locale ?? "")|\(appBundleID ?? "")|\(markKind?.rawValue ?? "")"
    }
}
