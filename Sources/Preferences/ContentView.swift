import SwiftUI

struct ContentView: View {
    @State private var spellers: [InstalledSpeller] = []
    @State private var selection: InstalledSpeller.ID?
    @State private var ruleStates: [InstalledSpeller.ID: RuleState] = [:]
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
            List(spellers, selection: $selection) { speller in
                row(for: speller).tag(speller.id as InstalledSpeller.ID?)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 240)
        } detail: {
            detailPane(for: selection)
        }
    }

    @ViewBuilder
    private var legacyLayout: some View {
        NavigationView {
            List(spellers, selection: $selection) { speller in
                row(for: speller).tag(speller.id as InstalledSpeller.ID?)
            }
            .frame(minWidth: 200)
            detailPane(for: selection)
        }
    }

    @ViewBuilder
    private func row(for speller: InstalledSpeller) -> some View {
        VStack(alignment: .leading) {
            Text(displayName(for: speller.locale))
            Text(speller.locale).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func displayName(for locale: String) -> String {
        Locale.current.localizedString(forIdentifier: locale) ?? locale
    }

    @ViewBuilder
    private func detailPane(for id: InstalledSpeller.ID?) -> some View {
        if let id = id,
           let speller = spellers.first(where: { $0.id == id }),
           let state = ruleStates[id] {
            detail(for: speller, state: state)
        } else if spellers.isEmpty {
            emptyState(
                title: "No speller bundles installed",
                systemImage: "questionmark.folder",
                message: "Drop a <lang>.bundle into ~/Library/Services or /Library/Services."
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
    private func detail(for speller: InstalledSpeller, state: RuleState) -> some View {
        switch state {
        case .loading:
            ProgressView().controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .error(let message):
            emptyState(title: "Couldn't load \(displayName(for: speller.locale))",
                       systemImage: "exclamationmark.triangle",
                       message: message)
        case .loaded(let rules, var ignored):
            List {
                Section(header: Text("Grammar rules for \(displayName(for: speller.locale))")) {
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
                                store.setIgnored(ignored, for: speller.locale)
                                ruleStates[speller.id] = .loaded(rules: rules, ignored: ignored)
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
        spellers = BundleDiscovery.discover()
        if selection == nil { selection = spellers.first?.id }
        for speller in spellers where ruleStates[speller.id] == nil {
            loadRules(for: speller)
        }
    }

    private func loadRules(for speller: InstalledSpeller) {
        ruleStates[speller.id] = .loading
        let storedIgnored = store.ignored(for: speller.locale)
        let drbPath = speller.drbURL.path
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
                    ruleStates[speller.id] = .loaded(rules: rules, ignored: storedIgnored)
                }
            } catch {
                await MainActor.run {
                    ruleStates[speller.id] = .error(message: error.localizedDescription)
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
