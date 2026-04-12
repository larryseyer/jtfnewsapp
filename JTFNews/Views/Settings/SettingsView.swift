import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var sources: [Source]

    @AppStorage("notifyCorrections") private var notifyCorrections = false
    @AppStorage("notifyBreakingFacts") private var notifyBreakingFacts = false
    @AppStorage("notifyWatchedTerms") private var notifyWatchedTerms = false
    @AppStorage("notifyLiveActivities") private var notifyLiveActivities = false
    @AppStorage("useCustomNotificationSound") private var useCustomNotificationSound = true
    @AppStorage("preferVideoMode") private var preferVideoMode = true
    @AppStorage("archiveDownloadMode") private var archiveDownloadMode = "wifi"
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    @State private var showWatchedTerms = false
    @State private var showPrivacyPolicy = false
    @State private var selectedSource: Source?

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
            #if os(macOS)
            .sheet(isPresented: $showWatchedTerms) {
                NavigationStack {
                    WatchedTermsView()
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { showWatchedTerms = false }
                            }
                        }
                }
                .frame(width: 400, height: 350)
            }
            .sheet(isPresented: $showPrivacyPolicy) {
                NavigationStack {
                    PrivacyPolicyView()
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { showPrivacyPolicy = false }
                            }
                        }
                }
                .frame(width: 500, height: 500)
            }
            .sheet(item: $selectedSource) { source in
                NavigationStack {
                    SourceDetailView(source: source)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { selectedSource = nil }
                            }
                        }
                }
                .frame(width: 450, height: 400)
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
                #if os(macOS)
                Button("Manage Watched Terms") { showWatchedTerms = true }
                #else
                NavigationLink("Manage Watched Terms") {
                    WatchedTermsView()
                }
                #endif
            }
            Toggle("Custom Sound", isOn: $useCustomNotificationSound)
                .accessibilityHint("Use the JTF News chime instead of the default notification sound")
            #if os(iOS)
            Toggle("Live Activities", isOn: $notifyLiveActivities)
                .onChange(of: notifyLiveActivities) { _, newValue in
                    if newValue { requestNotificationPermission() }
                }
                .accessibilityHint("Show new facts on Lock Screen and Dynamic Island")
            #endif
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
                #if os(macOS)
                Button {
                    selectedSource = source
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
                .buttonStyle(.plain)
                #else
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
                #endif
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
            Link(destination: URL(string: "https://jtfnews.org/support.html")!) {
                Label("Support JTF News", systemImage: "heart")
            }
            #if os(macOS)
            Button("Privacy Policy") { showPrivacyPolicy = true }
            #else
            NavigationLink("Privacy Policy") {
                PrivacyPolicyView()
            }
            #endif
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
