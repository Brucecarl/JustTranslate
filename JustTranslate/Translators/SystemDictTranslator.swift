import Foundation
import ApplicationServices
import CoreServices

// MARK: - Accessibility & Dictionary Utilities
class AccessibilityUtils {
    static func getSelectedText() -> String? {
        // 0. 安全检查：如果没权限，直接返回，避免触发系统级错误日志
        guard AXIsProcessTrusted() else { return nil }

        // 1. 获取系统级 Accessibility 对象
        let systemWide = AXUIElementCreateSystemWide()
        var focusedElement: CFTypeRef?

        // 2. 获取当前焦点元素 (使用 CFTypeRef 指针，避免 AnyObject 桥接问题)
        let error = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedElement)

        // 确保获取成功且元素存在
        guard error == .success, let element = focusedElement else { return nil }

        var selectedTextValue: CFTypeRef?

        // 3. 尝试获取该元素的选中文本 (强制转换为 AXUIElement)
        let textError = AXUIElementCopyAttributeValue(element as! AXUIElement, kAXSelectedTextAttribute as CFString, &selectedTextValue)

        // 4. 安全转换为 String
        if textError == .success, let text = selectedTextValue as? String {
            return text
        }

        return nil
    }

    static func getDefinition(for text: String) -> String? {
        // 空字符串或过长字符串可能导致 CoreServices 内部解码错误
        if text.isEmpty || text.count > 1000 { return nil }

        // 使用 utf16 长度创建 Range，确保 emoji 不会破坏索引
        let range = CFRangeMake(0, text.utf16.count)

        // DCSCopyTextDefinition 可能会在某些特殊字符上失败，这里我们做了基本的安全防护
        if let definition = DCSCopyTextDefinition(nil, text as CFString, range) {
            return definition.takeRetainedValue() as String
        }
        return nil
    }
}

/// 使用系统词典作为翻译/定义提供者
final class SystemDictTranslator: Translator {
    let name: String = "System"
    var config: TranslatorConfig = TranslatorConfig()

    func translate(text: String) async throws -> String? {
        // 调用同步 API，快速返回
        return AccessibilityUtils.getDefinition(for: text)
    }
}
