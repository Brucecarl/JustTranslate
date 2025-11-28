import Foundation
import ApplicationServices
import CoreServices

// MARK: - Accessibility & Dictionary Utilities
class AccessibilityUtils {
    static func getSelectedText() -> String? {
        // 0. Security check: if there is no permission, return directly to avoid triggering system-level error logs
        guard AXIsProcessTrusted() else { return nil }

        // 1. Get system-level Accessibility object
        let systemWide = AXUIElementCreateSystemWide()
        var focusedElement: CFTypeRef?

        // 2. Get the current focus element (use CFTypeRef pointer to avoid AnyObject bridging problems)
        let error = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedElement)

        // Make sure the acquisition is successful and the element exists
        guard error == .success, let element = focusedElement else { return nil }

        var selectedTextValue: CFTypeRef?

        // 3. Try to get the selected text of this element (force cast to AXUIElement)
        let textError = AXUIElementCopyAttributeValue(element as! AXUIElement, kAXSelectedTextAttribute as CFString, &selectedTextValue)

        // 4. Safely convert to String
        if textError == .success, let text = selectedTextValue as? String {
            return text
        }

        return nil
    }

    static func getDefinition(for text: String) -> String? {
        // Empty or too long strings may cause internal decoding errors in CoreServices
        if text.isEmpty || text.count > 1000 { return nil }

        // Use utf16 length to create a Range to ensure that emoji will not break the index
        let range = CFRangeMake(0, text.utf16.count)

        // DCSCopyTextDefinition may fail on some special characters, here we have done basic security protection
        if let definition = DCSCopyTextDefinition(nil, text as CFString, range) {
            return definition.takeRetainedValue() as String
        }
        return nil
    }
}

/// Use system dictionary as translation/definition provider
final class SystemDictTranslator: Translator {
    let name: String = "System"
    var config: TranslatorConfig = TranslatorConfig()

    func translate(text: String) async throws -> String? {
        // Call the sync API for a quick return
        return AccessibilityUtils.getDefinition(for: text)
    }
}
