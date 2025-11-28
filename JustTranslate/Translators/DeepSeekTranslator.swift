import Foundation

// MARK: - Models for DeepSeek
struct DeepSeekResponse: Codable, Sendable {
    struct Choice: Codable, Sendable {
        struct Message: Codable, Sendable {
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}

// MARK: - DeepSeek API Service (async/throws)
final class DeepSeekService: Sendable {
    static let shared = DeepSeekService()

    // DeepSeekService no longer stores an API key internally; callers must provide apiKey & prompt via parameters.

    private let apiUrl = URL(string: "https://api.deepseek.com/chat/completions")!

    /// Translates text, the caller needs to provide an `apiKey` and an optional `prompt` (if the `prompt` is empty, the default prompt is used)
    func translate(text: String, apiKey: String?, prompt: String?) async throws -> String {
        let key = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !key.isEmpty else {
            throw NSError(domain: "DeepSeekService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing DeepSeek API Key. Provide via Translator.config.apiKey."])
        }

        var request = URLRequest(url: apiUrl)
        request.httpMethod = "POST"
        request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let usedPrompt: String
        if let p = prompt, !p.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            usedPrompt = p+text
        } else {
            usedPrompt = "You are an export translator.Translate the following text between Simplified Chinese and English. Provide only the translation. Text:\(text)"
        }

        let body: [String: Any] = [
            "model": "deepseek-chat",
            "messages": [
                ["role": "system", "content": "You are a helpful translator."],
                ["role": "user", "content": usedPrompt]
            ],
            "stream": false
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "DeepSeekService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid response"]) 
        }

        if !(200...299).contains(http.statusCode) {
            let bodyStr = String(data: data, encoding: .utf8) ?? "(binary)"
            throw NSError(domain: "DeepSeekService", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "API error: \(http.statusCode) - \(bodyStr)"])
        }

        let decoded = try JSONDecoder().decode(DeepSeekResponse.self, from: data)
        return decoded.choices.first?.message.content ?? ""
    }
}

/// DeepSeek translator, encapsulates DeepSeekService calls
final class DeepSeekTranslator: Translator {
    let name: String = "DeepSeek"
    var config: TranslatorConfig

    init(config: TranslatorConfig = TranslatorConfig()) {
        self.config = config
    }

    func translate(text: String) async throws -> String? {
        let res = try await DeepSeekService.shared.translate(text: text, apiKey: config.apiKey, prompt: config.prompt)
        return res
    }
}
