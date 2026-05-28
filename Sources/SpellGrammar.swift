import Foundation

struct PipelineResponse: Decodable, Sendable {
    let errors: [PipelineError]
}

struct PipelineError: Decodable, Sendable {
    let errorId: String
    let start: Int
    let end: Int
    let title: String?
    let description: String?
    let suggestions: [String]?

    enum CodingKeys: String, CodingKey {
        case errorId = "error_id"
        case start, end, title, description, suggestions
    }

    var nsRange: NSRange { NSRange(location: start, length: max(0, end - start)) }
}

// Matches the rule used in divvunspell-libreoffice (native/ErrorClass.hxx).
// Anything not classified as a spell error is treated as a grammar error.
func isSpellError(_ id: String) -> Bool {
    id == "typo" || id == "spelling-error"
        || id.hasPrefix("real-") || id.hasPrefix("orth-")
}
