import SwiftUI

// MARK: - Storage

private enum WatchedTermsKeys {
    static let terms = "watchedTerms"
    static let notifiedHashes = "watchedTermsNotifiedHashes"
}

@Observable
@MainActor
final class WatchedTermsStorage {
    static let shared = WatchedTermsStorage()
    static let maxTerms = 10

    var terms: [String] {
        didSet {
            let data = try? JSONEncoder().encode(terms)
            UserDefaults.standard.set(data, forKey: WatchedTermsKeys.terms)
        }
    }

    var notifiedHashes: Set<String> {
        didSet {
            let data = try? JSONEncoder().encode(notifiedHashes)
            UserDefaults.standard.set(data, forKey: WatchedTermsKeys.notifiedHashes)
        }
    }

    private init() {
        self.terms = (UserDefaults.standard.data(forKey: WatchedTermsKeys.terms)
            .flatMap { try? JSONDecoder().decode([String].self, from: $0) }) ?? []
        self.notifiedHashes = (UserDefaults.standard.data(forKey: WatchedTermsKeys.notifiedHashes)
            .flatMap { try? JSONDecoder().decode(Set<String>.self, from: $0) }) ?? []
    }
}

// Non-isolated static facade. Reads/writes UserDefaults directly so
// background services (BackgroundRefreshManager, WatchedTermMatcher) can
// touch the store from any actor. SwiftUI views should use `.shared` so
// reads register as observable dependencies.
extension WatchedTermsStorage {
    nonisolated static var terms: [String] {
        get {
            (UserDefaults.standard.data(forKey: WatchedTermsKeys.terms)
                .flatMap { try? JSONDecoder().decode([String].self, from: $0) }) ?? []
        }
        set {
            let data = try? JSONEncoder().encode(newValue)
            UserDefaults.standard.set(data, forKey: WatchedTermsKeys.terms)
        }
    }

    nonisolated static var notifiedHashes: Set<String> {
        get {
            (UserDefaults.standard.data(forKey: WatchedTermsKeys.notifiedHashes)
                .flatMap { try? JSONDecoder().decode(Set<String>.self, from: $0) }) ?? []
        }
        set {
            let data = try? JSONEncoder().encode(newValue)
            UserDefaults.standard.set(data, forKey: WatchedTermsKeys.notifiedHashes)
        }
    }
}

// MARK: - View

struct WatchedTermsView: View {
    private let storage = WatchedTermsStorage.shared
    @State private var newTerm = ""

    var body: some View {
        Form {
            Section {
                if storage.terms.isEmpty {
                    Text("No watched terms yet. Add one below to get notified when matching facts are published.")
                        .font(.jtfCallout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(storage.terms, id: \.self) { term in
                        termRow(term)
                    }
                    .onDelete(perform: deleteTerm)
                }
            } header: {
                Text("Terms (\(storage.terms.count)/\(WatchedTermsStorage.maxTerms))")
            } footer: {
                Text("Case-insensitive match against story text. All matching is done on-device.")
                    .font(.jtfCaption)
            }

            if storage.terms.count < WatchedTermsStorage.maxTerms {
                Section("Add Term") {
                    HStack {
                        TextField("New term", text: $newTerm)
                            .autocorrectionDisabled()
                            .onSubmit { addTerm() }
                        Button("Add") { addTerm() }
                            .disabled(newTerm.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Watched Terms")
        #if os(iOS)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
        }
        #endif
    }

    @ViewBuilder
    private func termRow(_ term: String) -> some View {
        #if os(macOS)
        // macOS has no EditButton / swipe-to-delete affordance, so give
        // each row an inline trash action so users can actually remove
        // terms without hunting for a gesture.
        HStack {
            Text(term)
                .font(.jtfBody)
            Spacer()
            Button {
                delete(term)
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
            .help("Remove this term")
        }
        #else
        Text(term)
            .font(.jtfBody)
        #endif
    }

    private func addTerm() {
        let trimmed = newTerm.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        guard !storage.terms.contains(where: { $0.lowercased() == trimmed.lowercased() }) else { return }
        var updated = storage.terms
        updated.append(trimmed)
        storage.terms = updated
        storage.notifiedHashes = []
        newTerm = ""
    }

    private func deleteTerm(at offsets: IndexSet) {
        var updated = storage.terms
        updated.remove(atOffsets: offsets)
        storage.terms = updated
        storage.notifiedHashes = []
    }

    private func delete(_ term: String) {
        var updated = storage.terms
        updated.removeAll { $0 == term }
        storage.terms = updated
        storage.notifiedHashes = []
    }
}
