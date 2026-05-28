import SwiftUI
import ApplicationServices

struct AccessibilitySettings: View {
    @State private var trusted: Bool = AXIsProcessTrusted()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("In-Line Feedback Button").font(.headline)
            if trusted {
                Label("Accessibility access granted.", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                Text("MacDivvun shows a small \"Report\" button near words it has flagged, in any app that exposes its text via Accessibility (most native apps + MS Office).")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Label("Accessibility access not granted.", systemImage: "exclamationmark.shield")
                    .foregroundStyle(.orange)
                Text("MacDivvun can show a small \"Report\" button next to misspellings while you type, in any app — but only after you grant Accessibility access in System Settings.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Button("Grant Accessibility Access…") {
                    let prompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
                    _ = AXIsProcessTrustedWithOptions([prompt: true] as CFDictionary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onReceive(Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()) { _ in
            trusted = AXIsProcessTrusted()
        }
    }
}
