import SwiftUI

struct ArchiveView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedDate = Date()
    @State private var availableDates: [String] = []
    @State private var archiveText: String?
    @State private var isLoadingIndex = true
    @State private var isLoadingDay = false
    @State private var errorMessage: String?
    @State private var showSearch = false

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DatePicker(
                    "Select Date",
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding(.horizontal, 16)

                Divider()

                contentArea
            }
            .navigationTitle("Archive")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                }
            }
            .navigationDestination(isPresented: $showSearch) {
                ArchiveSearchView()
            }
            .task { await loadIndex() }
            .onChange(of: selectedDate) {
                Task { await loadDay() }
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentArea: some View {
        if isLoadingDay {
            ProgressView("Loading archive...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title)
                    .foregroundStyle(.secondary)
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let text = archiveText {
            ScrollView {
                Text(text)
                    .font(.body)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "archivebox")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                Text("Select a date to view archived stories")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Load

    private func loadIndex() async {
        let service = ArchiveService(modelContainer: modelContext.container)
        do {
            availableDates = try await service.fetchIndex()
        } catch {
            // Graceful degradation
        }
        isLoadingIndex = false
    }

    private func loadDay() async {
        let dateString = dateFormatter.string(from: selectedDate)
        isLoadingDay = true
        errorMessage = nil
        archiveText = nil

        let service = ArchiveService(modelContainer: modelContext.container)
        do {
            archiveText = try await service.fetchDay(dateString: dateString)
        } catch {
            errorMessage = "Archive not available for \(dateString)"
        }
        isLoadingDay = false
    }
}

#Preview {
    ArchiveView()
        .preferredColorScheme(.dark)
}
