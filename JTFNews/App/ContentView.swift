import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            StoriesView()
                .tabItem {
                    Label("Stories", systemImage: "newspaper")
                }

            DigestView()
                .tabItem {
                    Label("Digest", systemImage: "play.circle")
                }

            ArchiveView()
                .tabItem {
                    Label("Archive", systemImage: "archivebox")
                }
        }
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
