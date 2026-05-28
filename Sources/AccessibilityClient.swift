import AppKit
import ApplicationServices

enum AccessibilityClient {
    struct Mark {
        var word: String
        var paragraph: String
        var kind: FeedbackPrefill.MarkKind
        var screenBounds: CGRect
        var appBundleID: String?
    }

    static func isTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    static func requestTrust() {
        let prompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([prompt: true] as CFDictionary)
    }

    /// Returns the focused text-bearing UI element, or nil if there isn't one.
    static func focusedElement() -> AXUIElement? {
        guard isTrusted() else { return nil }
        let system = AXUIElementCreateSystemWide()
        guard let raw = copyAXValue(system, kAXFocusedUIElementAttribute as CFString) else { return nil }
        return (raw as! AXUIElement)
    }

    /// Given a focused element, return a Mark iff the caret/selection sits inside
    /// a misspelled-or-grammar-marked run.
    static func reportableMark(in element: AXUIElement) -> Mark? {
        guard let selectionRange = copySelectedRange(element) else { return nil }
        let probeRange = expandToLineRange(selectionRange, in: element)
        guard let probeAttr = attributedString(for: probeRange, in: element) else { return nil }

        guard let (markLocalRange, kind) = findMark(in: probeAttr) else { return nil }
        let wordPlain = (probeAttr.string as NSString).substring(with: markLocalRange)

        let markAbsRange = CFRange(location: probeRange.location + markLocalRange.location,
                                   length: markLocalRange.length)

        // Paragraph context: the line range we already pulled.
        let paragraphPlain = probeAttr.string

        // Screen bounds: ask AX for bounds-for-range over the marked run.
        guard let bounds = boundsForRange(markAbsRange, in: element) else { return nil }

        return Mark(
            word: wordPlain,
            paragraph: paragraphPlain,
            kind: kind,
            screenBounds: bounds,
            appBundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        )
    }

    // MARK: - Low-level helpers

    private static func copyAXValue(_ element: AXUIElement, _ attribute: CFString) -> AnyObject? {
        var value: AnyObject?
        let err = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard err == .success else { return nil }
        return value
    }

    private static func copySelectedRange(_ element: AXUIElement) -> CFRange? {
        guard let raw = copyAXValue(element, kAXSelectedTextRangeAttribute as CFString) else { return nil }
        let axValue = raw as! AXValue
        var range = CFRange(location: 0, length: 0)
        guard AXValueGetValue(axValue, .cfRange, &range) else { return nil }
        return range
    }

    private static func attributedString(for range: CFRange, in element: AXUIElement) -> NSAttributedString? {
        var r = range
        guard let value = AXValueCreate(.cfRange, &r) else { return nil }
        var result: AnyObject?
        let err = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXAttributedStringForRangeParameterizedAttribute as CFString,
            value,
            &result
        )
        guard err == .success, let attr = result as? NSAttributedString else { return nil }
        return attr
    }

    private static func boundsForRange(_ range: CFRange, in element: AXUIElement) -> CGRect? {
        var r = range
        guard let value = AXValueCreate(.cfRange, &r) else { return nil }
        var result: AnyObject?
        let err = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            value,
            &result
        )
        guard err == .success, let axValue = result else { return nil }
        var rect = CGRect.zero
        guard AXValueGetValue(axValue as! AXValue, .cgRect, &rect) else { return nil }
        return rect
    }

    private static func expandToLineRange(_ selection: CFRange, in element: AXUIElement) -> CFRange {
        if let line = lineRangeContaining(selection, in: element) {
            return line
        }
        // Fallback: pad ~80 chars each side.
        let value = (copyAXValue(element, kAXValueAttribute as CFString) as? String) ?? ""
        let length = (value as NSString).length
        let pad = 80
        let start = max(0, selection.location - pad)
        let end = min(length, selection.location + max(selection.length, 1) + pad)
        return CFRange(location: start, length: max(0, end - start))
    }

    private static func lineRangeContaining(_ range: CFRange, in element: AXUIElement) -> CFRange? {
        var lineIndexAny: AnyObject?
        let err1 = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXLineForIndexParameterizedAttribute as CFString,
            NSNumber(value: range.location) as CFTypeRef,
            &lineIndexAny
        )
        guard err1 == .success, let lineIndexNum = lineIndexAny as? NSNumber else { return nil }
        var rangeAny: AnyObject?
        let err2 = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXRangeForLineParameterizedAttribute as CFString,
            lineIndexNum as CFTypeRef,
            &rangeAny
        )
        guard err2 == .success, let rangeAXValue = rangeAny else { return nil }
        var resolved = CFRange(location: 0, length: 0)
        guard AXValueGetValue(rangeAXValue as! AXValue, .cfRange, &resolved) else { return nil }
        return resolved
    }

    /// Walk the attributed string's runs and find the first carrying a misspelled-or-grammar mark.
    /// Returns the range *relative to the attributed string* (which itself starts at probe-range start).
    private static func findMark(in attributed: NSAttributedString) -> (NSRange, FeedbackPrefill.MarkKind)? {
        let full = NSRange(location: 0, length: attributed.length)
        var result: (NSRange, FeedbackPrefill.MarkKind)?
        attributed.enumerateAttributes(in: full, options: []) { attrs, range, stop in
            if let value = attrs[NSAttributedString.Key(rawValue: "AXMarkedMisspelledText")] as? Bool, value {
                result = (range, .grammar)
                stop.pointee = true
                return
            }
            if let value = attrs[NSAttributedString.Key(rawValue: "AXMisspelledText")] as? Bool, value {
                result = (range, .spelling)
                stop.pointee = true
                return
            }
        }
        return result
    }
}
