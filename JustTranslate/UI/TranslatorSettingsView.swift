import SwiftUI
import AppKit

struct TranslatorSettingsView: View {
    @State private var configs: [String: TranslatorConfig] = [:]
    @State private var names: [String] = []
    @State private var statusMessage: String = ""

    var body: some View {
        VStack(alignment: .leading) {
            Text("Translator Settings")
                .font(.title2)
                .padding(.bottom, 8)

            if names.isEmpty {
                Text("No translators available.")
                    .foregroundColor(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(names, id: \ .self) { name in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(name)
                                    .font(.headline)

                                TextField("API Key", text: Binding(get: {
                                    configs[name]?.apiKey ?? ""
                                }, set: { new in
                                    var c = configs[name] ?? TranslatorConfig()
                                    c.apiKey = new
                                    configs[name] = c
                                }))
                                .textFieldStyle(RoundedBorderTextFieldStyle())

                                Text("Prompt")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                TextEditor(text: Binding(get: {
                                    configs[name]?.prompt ?? ""
                                }, set: { new in
                                    var c = configs[name] ?? TranslatorConfig()
                                    c.prompt = new
                                    configs[name] = c
                                }))
                                .frame(minHeight: 80)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2)))
                            }
                            .padding(8)
                            .background(Color(NSColor.windowBackgroundColor))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            HStack {
                Button(action: save) {
                    Text("Save")
                }
                Spacer()
                Text(statusMessage)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)

        }
        .padding(16)
        .frame(minWidth: 480, minHeight: 320)
        .onAppear(perform: load)
    }

    private func load() {
        // Load saved configs
        let loaded = TranslatorConfigLoader.load()
        self.configs = loaded

        // Fallback to common translators
        self.names = ["DeepSeek"]
        for n in names { if configs[n] == nil { configs[n] = TranslatorConfig() } }
    }

    private func save() {
        do {
            try TranslatorConfigLoader.save(configs)
            // Update live translators in AppDelegate
            if let app = NSApp.delegate as? AppDelegate {
                app.updateTranslators(with: configs)
            }
            statusMessage = "Saved"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { statusMessage = "" }
        } catch {
            statusMessage = "Save failed: \(error.localizedDescription)"
        }
    }
}

struct TranslatorSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        TranslatorSettingsView()
    }
}
