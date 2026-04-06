import SwiftUI

struct ContentView: View {
    @State private var audioManager = AudioManager()
    @State private var searchIndexer = SearchIndexer()
    @State private var connectivity = ConnectivityManager()
    @State private var selectedTab = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                StoriesView()
                    .tabItem {
                        Label("Stories", systemImage: "newspaper")
                    }
                    .tag(0)

                DigestView()
                    .tabItem {
                        Label("Digest", systemImage: "play.circle")
                    }
                    .tag(1)

                ArchiveView()
                    .tabItem {
                        Label("Archive", systemImage: "archivebox")
                    }
                    .tag(2)
            }

            if audioManager.hasActiveAudio && selectedTab != 1 {
                MiniPlayerView()
                    .onTapGesture {
                        selectedTab = 1
                    }
                    .padding(.bottom, 49) // tab bar height
                    .transition(.move(edge: .bottom))
            }
        }
        .environment(audioManager)
        .environment(searchIndexer)
        .environment(connectivity)
        .animation(.easeInOut(duration: 0.2), value: audioManager.hasActiveAudio)
        .onAppear { connectivity.start() }
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
