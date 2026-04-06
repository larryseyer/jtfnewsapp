import SwiftUI

struct StoriesView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Text("Stories")
                    .font(.title)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Stories")
        }
    }
}

#Preview {
    StoriesView()
        .preferredColorScheme(.dark)
}
