import Foundation

/// 统一的翻译器协议（Swift Concurrency 版本）
protocol Translator {
    /// 显示名称（用于 UI 标题）
    var name: String { get }

    /// 每个翻译器的可配置项
    var config: TranslatorConfig { get set }

    /// 异步翻译方法：返回可选字符串（nil 表示无结果），遇到错误请抛出异常
    func translate(text: String) async throws -> String?
}

/// 每个翻译器的可配置项
struct TranslatorConfig: Codable {
    /// API Key（大多数线上服务需要）
    var apiKey: String = ""
    /// Prompt / system message 等可自定义提示文本
    var prompt: String = "You are an export translator.Translate the following text between Simplified Chinese and English. Provide only the translation. Text:"
}
