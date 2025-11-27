import Foundation

enum TranslatorConfigLoader {
    static let fileName = "translators.json"

    /// Returns the Application Support URL for JustTranslate, creating folders if needed
    static func appSupportDirectory() -> URL? {
        let fm = FileManager.default
        if let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let dir = appSupport.appendingPathComponent("JustTranslate", isDirectory: true)
            if !fm.fileExists(atPath: dir.path) {
                do { try fm.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil) } catch {
                    print("[TranslatorConfigLoader] failed to create app support dir: \(error)")
                    return nil
                }
            }
            return dir
        }
        return nil
    }

    /// Default path for the translators config file
    static func configFileURL() -> URL? {
        guard let dir = appSupportDirectory() else { return nil }
        return dir.appendingPathComponent(fileName)
    }

    /// Load translator configs mapping translator `name` -> `TranslatorConfig`
    static func load() -> [String: TranslatorConfig] {
        guard let url = configFileURL() else { return [:] }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let mapping = try decoder.decode([String: TranslatorConfig].self, from: data)
            return mapping
        } catch {
            // If file missing or decode failed, log and return empty mapping
            if (error as NSError).code == NSFileReadNoSuchFileError {
                // no config yet
                return [:]
            }
            print("[TranslatorConfigLoader] failed to load config: \(error)")
            return [:]
        }
    }

    /// Save translator configs mapping to file
    static func save(_ mapping: [String: TranslatorConfig]) throws {
        guard let url = configFileURL() else { throw NSError(domain: "TranslatorConfigLoader", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot access app support directory"]) }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(mapping)
        try data.write(to: url, options: [.atomic])
    }
}
