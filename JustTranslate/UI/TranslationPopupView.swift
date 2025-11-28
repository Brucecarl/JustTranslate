import SwiftUI
import AppKit
import Combine

// MARK: - ViewModel
struct TranslationItem: Identifiable {
    let id: UUID
    let name: String
    var content: String
    var isLoading: Bool = false
    init(id: UUID = UUID(), name: String, content: String, isLoading: Bool = false) {
        self.id = id
        self.name = name
        self.content = content
        self.isLoading = isLoading
    }
}

class TranslationViewModel: ObservableObject {
    @Published var originalText: String = ""
    @Published var items: [TranslationItem] = []
    @Published var expandedStates: [UUID: Bool] = [:]

    func reset() {
        originalText = ""
        items.removeAll()
        expandedStates.removeAll()
    }

    func setItem(_ item: TranslationItem) {
        if let idx = items.firstIndex(where: { $0.name == item.name }) {
            // preserve existing id
            let existing = items[idx]
            let newItem = TranslationItem(id: existing.id, name: item.name, content: item.content, isLoading: item.isLoading)
            items[idx] = newItem
            expandedStates[newItem.id] = expandedStates[existing.id] ?? true
        } else {
            items.append(item)
            expandedStates[item.id] = true
        }
    }
}

// MARK: - SwiftUI Views
struct TranslationPopupView: View {
    @ObservedObject var viewModel: TranslationViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text(viewModel.originalText)
                    .font(.headline)
                    .lineLimit(1)
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "character.book.closed.fill")
                    .foregroundColor(.yellow)
            }
            .padding(12)
            .background(Color.black.opacity(0.3))

            Divider().background(Color.white.opacity(0.2))

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.items) { item in
                        let isExpanded = Binding(get: { viewModel.expandedStates[item.id] ?? true }, set: { viewModel.expandedStates[item.id] = $0 })

                        DisclosureGroup(isExpanded: isExpanded) {
                            if item.isLoading {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.5)
                                                                         Text("Loading...")                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 5)
                            } else {
                                Text(item.content)
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.9))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .textSelection(.enabled)
                                    .padding(.top, 5)
                            }
                        } label: {
                            HStack {
                                Text(item.name)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                        }
                        .accentColor(.white.opacity(0.6))

                        Divider().background(Color.white.opacity(0.12))
                    }
                }
                .padding(12)
            }
            .frame(maxHeight: 350)
        }
        .frame(width: 320)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
    }
}

// MARK: - Visual Effect View
struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
