import SwiftUI

// MARK: - Storage

enum WatchedTermsStorage {
    static let maxTerms = 10

    static var terms: [String] {
        get {
            guard let data = UserDefaults.standard.data(forKey: "watchedTerms"),
                  let decoded = try? JSONDecoder().decode([String].self, from: data)
            else { return [] }
            return decoded
        }
        set {
            let data = try? JSONEncoder().encode(newValue)
            UserDefaults.standard.set(data, forKey: "watchedTerms")
        }
    }

    static var notifiedHashes: Set<String> {
        get {
            guard let data = UserDefaults.standard.data(forKey: "watchedTermsNotifiedHashes"),
                  let decoded = try? JSONDecoder().decode(Set<String>.self, from: data)
            else { return [] }
            return decoded
        }
        set {
            let data = try? JSONEncoder().encode(newValue)
            UserDefaults.standard.set(data, forKey: "watchedTermsNotifiedHashes")
        }
    }
}

// MARK: - View

struct WatchedTermsView: View {
    @State private var terms: [String] = WatchedTermsStorage.terms
    @State private var newTerm = ""

    var body: some View {
        Form {
            Section {
                ForEach(terms, id: \.self) { term in
                    Text(term)
                }
                .onDelete(perform: deleteTerm)
            } header: {
                Text("Terms (\(terms.count)/\(WatchedTermsStorage.maxTerms))")
            } footer: {
                Text("Case-insensitive match against story text. All matching is done on-device.")
            }

            if terms.count < WatchedTermsStorage.maxTerms {
                Section {
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
        .navigationTitle("Watched Terms")
    }

    private func addTerm() {
        let trimmed = newTerm.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        guard !terms.contains(where: { $0.lowercased() == trimmed.lowercased() }) else { return }
        terms.append(trimmed)
        newTerm = ""
        save()
    }

    private func deleteTerm(at offsets: IndexSet) {
        terms.remove(atOffsets: offsets)
        save()
    }

    private func save() {
        WatchedTermsStorage.terms = terms
        WatchedTermsStorage.notifiedHashes = []
    }
}
