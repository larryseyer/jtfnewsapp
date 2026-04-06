import SwiftUI

struct DigestView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Text("Digest")
                    .font(.title)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Digest")
        }
    }
}

#Preview {
    DigestView()
        .preferredColorScheme(.dark)
}
