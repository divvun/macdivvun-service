import Foundation

struct InstalledBundle: Identifiable, Hashable {
    let locale: String
    let bundleURL: URL
    let drbURL: URL

    var id: String { locale }
}

enum BundleDiscovery {
    static let searchPaths: [String] = [
        "\(NSHomeDirectory())/Library/Services",
        "/Library/Services",
    ]

    static func discover() -> [InstalledBundle] {
        let fm = FileManager.default
        var byLocale: [String: InstalledBundle] = [:]
        for root in searchPaths {
            guard let entries = fm.subpaths(atPath: root) else { continue }
            for entry in entries where entry.hasSuffix(".bundle") {
                let bundleURL = URL(fileURLWithPath: "\(root)/\(entry)", isDirectory: true)
                let locale = bundleURL.deletingPathExtension().lastPathComponent
                if byLocale[locale] != nil { continue }
                let resources = bundleURL
                    .appendingPathComponent("Contents")
                    .appendingPathComponent("Resources")
                guard let drbName = (try? fm.contentsOfDirectory(atPath: resources.path))?
                    .first(where: { $0.hasSuffix(".drb") }) else { continue }
                byLocale[locale] = InstalledBundle(
                    locale: locale,
                    bundleURL: bundleURL,
                    drbURL: resources.appendingPathComponent(drbName)
                )
            }
        }
        return byLocale.values.sorted { $0.locale < $1.locale }
    }
}
