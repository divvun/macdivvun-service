import Foundation

struct InstalledSpeller: Identifiable, Hashable {
    let locale: String          // canonical BCP47
    let drbURL: URL
    let parentBundleURL: URL

    var id: String { locale }
}

enum BundleDiscovery {
    static let searchPaths: [String] = [
        "\(NSHomeDirectory())/Library/Services",
        "/Library/Services",
    ]

    static func discover() -> [InstalledSpeller] {
        let fm = FileManager.default
        var byLocale: [String: InstalledSpeller] = [:]
        for root in searchPaths {
            guard let entries = fm.subpaths(atPath: root) else { continue }
            for entry in entries where entry.hasSuffix(".bundle") {
                let bundleURL = URL(fileURLWithPath: "\(root)/\(entry)", isDirectory: true)
                let resources = bundleURL
                    .appendingPathComponent("Contents")
                    .appendingPathComponent("Resources")
                guard let files = try? fm.contentsOfDirectory(atPath: resources.path) else { continue }
                for file in files.sorted() where file.hasSuffix(".drb") {
                    let drbURL = resources.appendingPathComponent(file)
                    let stem = (file as NSString).deletingPathExtension
                    let locale = NSLocale.canonicalLanguageIdentifier(from: stem)
                    if byLocale[locale] != nil { continue }
                    byLocale[locale] = InstalledSpeller(
                        locale: locale,
                        drbURL: drbURL,
                        parentBundleURL: bundleURL
                    )
                }
            }
        }
        return byLocale.values.sorted { $0.locale < $1.locale }
    }
}
