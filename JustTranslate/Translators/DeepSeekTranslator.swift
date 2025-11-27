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

    // API Key 加载策略：优先从 UserDefaults (`DeepSeekAPIKey`)，其次从环境变量 `DEEPSEEK_API_KEY`。
    private var apiKey: String? {
        // if let key = UserDefaults.standard.string(forKey: "DeepSeekAPIKey"), !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        //     return key
        // }
        // if let env = ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"], !env.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        //     return env
        // }
        return "sk-e28fbe447b8a47528a3d508f4b9eaa58"
    }

    private let apiUrl = URL(string: "https://api.deepseek.com/chat/completions")!

    func translate(text: String) async throws -> String {
        guard let key = apiKey, !key.isEmpty else {
            throw NSError(domain: "DeepSeekService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing DeepSeek API Key. Set DEEPSEEK_API_KEY or DeepSeekAPIKey in UserDefaults."])
        }

        var request = URLRequest(url: apiUrl)
        request.httpMethod = "POST"
        request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let prompt = """
        Translate the following text into Simplified Chinese. 
        If it is already Chinese, translate to English.
        Provide ONLY the translation.
        Text: \(text)
        """

        let body: [String: Any] = [
            "model": "deepseek-chat",
            "messages": [
                ["role": "system", "content": "You are a helpful translator."],
                ["role": "user", "content": prompt]
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

/// DeepSeek 翻译器，封装 DeepSeekService 调用
final class DeepSeekTranslator: Translator {
    let name: String = "DeepSeek"

    func translate(text: String) async throws -> String? {
        let res = try await DeepSeekService.shared.translate(text: text)
        return res
    }
}
