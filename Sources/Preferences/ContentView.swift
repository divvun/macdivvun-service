import SwiftUI

struct ContentView: View {
    @State private var bundles: [InstalledBundle] = []
    @State private var selection: InstalledBundle.ID?
    @State private var ruleStates: [InstalledBundle.ID: RuleState] = [:]
    private let store = IgnoredRulesStore()

    var body: some View {
        Group {
            if #available(macOS 13, *) {
                modernLayout
            } else {
                legacyLayout
            }
        }
        .onAppear(perform: reload)
    }

    @available(macOS 13, *)
    @ViewBuilder
    private var modernLayout: some View {
        NavigationSplitView {
            List(bundles, selection: $selection) { bundle in
                Text(bundle.locale).tag(bundle.id as InstalledBundle.ID?)
            }
            .navigationSplitViewColumnWidth(min: 140, ideal: 180)
        } detail: {
            detailPane(for: selection)
        }
    }

    @ViewBuilder
    private var legacyLayout: some View {
        NavigationView {
            List(bundles, selection: $selection) { bundle in
                Text(bundle.locale).tag(bundle.id as InstalledBundle.ID?)
            }
            .frame(minWidth: 160)
            detailPane(for: selection)
        }
    }

    @ViewBuilder
    private func detailPane(for id: InstalledBundle.ID?) -> some View {
        if let id = id,
           let bundle = bundles.first(where: { $0.id == id }),
           let state = ruleStates[id] {
            detail(for: bundle, state: state)
        } else if bundles.isEmpty {
            emptyState(
                title: "No speller bundles installed",
                systemImage: "questionmark.folder",
                message: "Drop a <locale>.bundle into ~/Library/Services or /Library/Services."
            )
        } else {
            emptyState(title: "Pick a language", systemImage: "globe", message: nil)
        }
    }

    @ViewBuilder
    private func emptyState(title: String, systemImage: String, message: String?) -> some View {
        if #available(macOS 14, *) {
            if let message = message {
                ContentUnavailableView(title, systemImage: systemImage, description: Text(message))
            } else {
                ContentUnavailableView(title, systemImage: systemImage)
            }
        } else {
            VStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text(title).font(.title3).bold()
                if let message = message {
                    Text(message)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func detail(for bundle: InstalledBundle, state: RuleState) -> some View {
        switch state {
        case .loading:
            ProgressView().controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .error(let message):
            emptyState(title: "Couldn't load \(bundle.locale)",
                       systemImage: "exclamationmark.triangle",
                       message: message)
        case .loaded(let rules, var ignored):
            List {
                Section(header: Text("Grammar rules for \(bundle.locale)")) {
                    if rules.isEmpty {
                        Text("This bundle reports no grammar rules.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(rules, id: \.id) { rule in
                        Toggle(isOn: Binding(
                            get: { !ignored.contains(rule.id) },
                            set: { enabled in
                                if enabled { ignored.remove(rule.id) }
                                else { ignored.insert(rule.id) }
                                store.setIgnored(ignored, for: bundle.locale)
                                ruleStates[bundle.id] = .loaded(rules: rules, ignored: ignored)
                            }
                        )) {
                            VStack(alignment: .leading) {
                                Text(rule.title)
                                Text(rule.id).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private func reload() {
        bundles = BundleDiscovery.discover()
        if selection == nil { selection = bundles.first?.id }
        for bundle in bundles where ruleStates[bundle.id] == nil {
            loadRules(for: bundle)
        }
    }

    private func loadRules(for bundle: InstalledBundle) {
        ruleStates[bundle.id] = .loading
        let storedIgnored = store.ignored(for: bundle.locale)
        let drbPath = bundle.drbURL.path
        let preferredLocales = preferredUILocales()
        Task.detached(priority: .userInitiated) {
            do {
                let drb = try Bundle.fromPath(drbPath)
                let raw = try drb.errorPreferences(locales: preferredLocales)
                let rules = raw
                    .filter { !isSpellError($0.key) }
                    .map { Rule(id: $0.key, title: $0.value) }
                    .sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
                await MainActor.run {
                    ruleStates[bundle.id] = .loaded(rules: rules, ignored: storedIgnored)
                }
            } catch {
                await MainActor.run {
                    ruleStates[bundle.id] = .error(message: error.localizedDescription)
                }
            }
        }
    }

    private func preferredUILocales() -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for tag in Locale.preferredLanguages + ["en"] {
            let canonical = Locale(identifier: tag).identifier
            if seen.insert(canonical).inserted {
                out.append(canonical)
            }
        }
        return out
    }
}

struct Rule: Hashable {
    let id: String
    let title: String
}

enum RuleState {
    case loading
    case error(message: String)
    case loaded(rules: [Rule], ignored: Set<String>)
}
