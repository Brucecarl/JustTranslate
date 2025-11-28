import Foundation

/// Unified translator protocol (Swift Concurrency version)
protocol Translator {
    /// Display name (for UI title)
    var name: String { get }

    /// Configurable items for each translator
    var config: TranslatorConfig { get set }

    /// Asynchronous translation method: returns an optional string (nil means no result), throws an exception when an error is encountered
    func translate(text: String) async throws -> String?
}

/// Configurable items for each translator
struct TranslatorConfig: Codable {
    /// API Key (required for most online services)
    var apiKey: String = ""
    /// Prompt / system message and other customizable prompt text
    var prompt: String = "You are an export translator.Translate the following text between Simplified Chinese and English. Provide only the translation. Text:"
}
