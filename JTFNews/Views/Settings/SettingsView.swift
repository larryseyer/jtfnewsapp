import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var sources: [Source]

    @AppStorage("notifyCorrections") private var notifyCorrections = false
    @AppStorage("notifyBreakingFacts") private var notifyBreakingFacts = false
    @AppStorage("notifyWatchedTerms") private var notifyWatchedTerms = false
    @AppStorage("preferVideoMode") private var preferVideoMode = true
    @AppStorage("archiveDownloadMode") private var archiveDownloadMode = "wifi"
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        NavigationStack {
            Form {
                notificationsSection
                digestSection
                archiveSection
                sourceDetailsSection
                aboutSection
            }
            .navigationTitle("Settings")
            #if os(iOS)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            #endif
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        Section("Notifications") {
            Toggle("Corrections", isOn: $notifyCorrections)
                .onChange(of: notifyCorrections) { _, newValue in
                    if newValue { requestNotificationPermission() }
                }
                .accessibilityHint("Notify when story corrections are published")
            Toggle("Breaking Facts", isOn: $notifyBreakingFacts)
                .onChange(of: notifyBreakingFacts) { _, newValue in
                    if newValue { requestNotificationPermission() }
                }
                .accessibilityHint("Notify for facts published within the last hour")
            Toggle("Watched Terms", isOn: $notifyWatchedTerms)
                .onChange(of: notifyWatchedTerms) { _, newValue in
                    if newValue { requestNotificationPermission() }
                }
                .accessibilityHint("Notify when new stories match your watched terms")
            if notifyWatchedTerms {
                NavigationLink("Manage Watched Terms") {
                    WatchedTermsView()
                }
            }
        }
    }

    private func requestNotificationPermission() {
        Task {
            await NotificationManager.shared.requestPermissionIfNeeded()
        }
    }

    // MARK: - Digest

    private var digestSection: some View {
        Section("Digest") {
            Picker("Preferred Mode", selection: $preferVideoMode) {
                Text("Video").tag(true)
                Text("Audio").tag(false)
            }
        }
    }

    // MARK: - Archive

    private var archiveSection: some View {
        Section("Archive Download") {
            Picker("Download Mode", selection: $archiveDownloadMode) {
                Text("Wi-Fi Only").tag("wifi")
                Text("Wi-Fi + Cellular").tag("any")
                Text("Manual").tag("manual")
            }
        }
    }

    // MARK: - Source Details

    private var sourceDetailsSection: some View {
        Section("Source Details (\(sources.count) sources)") {
            ForEach(sources.sorted(by: { $0.name < $1.name }), id: \.name) { source in
                NavigationLink {
                    SourceDetailView(source: source)
                } label: {
                    HStack {
                        Text(source.name)
                            .font(.body)
                        Spacer()
                        Text(String(format: "%.1f", source.accuracy))
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.green.opacity(0.8))
                    }
                }
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("About JTF News") {
            Link("JTFNews.org", destination: URL(string: "https://jtfnews.org")!)
            Link("Whitepaper & Methodology", destination: URL(string: "https://jtfnews.org/whitepaper.html")!)
            Link(destination: URL(string: "https://jtfnews.org/submit.html")!) {
                Label("Submit a Story", systemImage: "square.and.pencil")
            }
            Link("Source Code (GitHub)", destination: URL(string: "https://github.com/larryseyer/JTFNews")!)
            NavigationLink("Privacy Policy") {
                PrivacyPolicyView()
            }
            Button("Show Welcome") {
                hasSeenOnboarding = false
                dismiss()
            }

            HStack {
                Text("Version")
                Spacer()
                Text("1.0")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
