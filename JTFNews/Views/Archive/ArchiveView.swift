import SwiftUI

struct ArchiveView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Text("Archive")
                    .font(.title)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Archive")
        }
    }
}

#Preview {
    ArchiveView()
        .preferredColorScheme(.dark)
}
