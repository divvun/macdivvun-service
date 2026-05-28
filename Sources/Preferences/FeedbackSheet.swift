import SwiftUI

struct FeedbackSheet: View {
    let prefill: FeedbackPrefill
    let onClose: () -> Void

    @State private var word: String
    @State private var paragraph: String
    @State private var locale: String
    @State private var comment: String = ""
    @State private var status: Status = .editing

    enum Status {
        case editing
        case sending
        case sent
        case failed(String)
    }

    init(prefill: FeedbackPrefill, onClose: @escaping () -> Void) {
        self.prefill = prefill
        self.onClose = onClose
        _word = State(initialValue: prefill.word ?? "")
        _paragraph = State(initialValue: prefill.paragraph ?? "")
        _locale = State(initialValue: prefill.locale ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.title2).bold()
            sourceBadge

            Form {
                TextField("Locale (BCP47)", text: $locale)
                TextField("Word or phrase", text: $word)
                VStack(alignment: .leading) {
                    Text("Context").font(.caption).foregroundStyle(.secondary)
                    TextEditor(text: $paragraph)
                        .frame(minHeight: 60)
                        .font(.body)
                }
                VStack(alignment: .leading) {
                    Text("Comment (optional)").font(.caption).foregroundStyle(.secondary)
                    TextEditor(text: $comment)
                        .frame(minHeight: 80)
                        .font(.body)
                }
            }

            statusFooter

            HStack {
                Spacer()
                Button("Close", action: onClose).keyboardShortcut(.cancelAction)
                Button(action: send) {
                    Text(sendLabel)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(disabled)
            }
        }
        .padding(20)
        .frame(width: 480, height: 460)
    }

    private var title: String {
        switch prefill.kind {
        case .suggestion: return "Report a Suggestion"
        case .missingWord: return "Suggest a Missing Word"
        }
    }

    @ViewBuilder
    private var sourceBadge: some View {
        if let bundleID = prefill.appBundleID {
            HStack(spacing: 6) {
                Image(systemName: "app.dashed")
                Text("From \(bundleID)").foregroundStyle(.secondary)
                if let kind = prefill.markKind {
                    Text("•").foregroundStyle(.secondary)
                    Text(kind.rawValue).foregroundStyle(.secondary)
                }
            }
            .font(.callout)
        }
    }

    @ViewBuilder
    private var statusFooter: some View {
        switch status {
        case .editing: EmptyView()
        case .sending: ProgressView("Sending…")
        case .sent: Label("Thanks — report sent.", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed(let msg): Label(msg, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
        }
    }

    private var sendLabel: String {
        switch status {
        case .sending: return "Sending…"
        case .sent: return "Sent"
        default: return "Send Report"
        }
    }

    private var disabled: Bool {
        switch status {
        case .sending, .sent: return true
        default: return word.isEmpty && comment.isEmpty
        }
    }

    private func send() {
        var prefilled = prefill
        prefilled.word = word.isEmpty ? nil : word
        prefilled.paragraph = paragraph.isEmpty ? nil : paragraph
        prefilled.locale = locale.isEmpty ? nil : locale

        status = .sending
        Task {
            do {
                try await FeedbackClient.submit(FeedbackClient.makePayload(prefill: prefilled, comment: comment.isEmpty ? nil : comment))
                await MainActor.run { status = .sent }
            } catch {
                await MainActor.run { status = .failed(error.localizedDescription) }
            }
        }
    }
}
