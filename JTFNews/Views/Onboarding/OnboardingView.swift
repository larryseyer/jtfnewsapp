import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var currentPage = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentPage) {
                OnboardingPage(
                    systemImage: "checkmark.shield",
                    title: "Facts Without Opinion",
                    description: "No tracking. No ads. No accounts. Just verified facts from independent sources."
                )
                .tag(0)

                OnboardingPage(
                    systemImage: "newspaper",
                    title: "Verified Stories",
                    description: "Every fact checked against two independent sources with different owners. Source ratings and ownership on every card."
                )
                .tag(1)

                OnboardingPage(
                    systemImage: "play.circle",
                    title: "Daily Digest",
                    description: "Watch or listen to the daily news digest. Video and audio, your choice."
                )
                .tag(2)

                OnboardingPage(
                    systemImage: "archivebox",
                    title: "Full Archive",
                    description: "Browse by date or search across every fact ever published."
                )
                .tag(3)

                OnboardingPage(
                    systemImage: "eye",
                    title: "Watch What Matters",
                    description: "Track stories by keyword. Get notified when matching facts are published.",
                    showButton: true
                ) {
                    hasSeenOnboarding = true
                }
                .tag(4)
            }
            #if os(iOS)
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            #endif
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Onboarding Page

private struct OnboardingPage: View {
    let systemImage: String
    let title: String
    let description: String
    var showButton: Bool = false
    var onGetStarted: (() -> Void)?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: systemImage)
                .font(.system(size: 72))
                .foregroundStyle(Color(red: 0.83, green: 0.69, blue: 0.22)) // #d4af37

            Text(title)
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(Color(red: 0.83, green: 0.69, blue: 0.22))
                .multilineTextAlignment(.center)

            Text(description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            if showButton {
                Button {
                    onGetStarted?()
                } label: {
                    Text("Get Started")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.83, green: 0.69, blue: 0.22))
                .padding(.horizontal, 40)
                .padding(.top, 8)
            }

            Spacer()
            Spacer()
        }
        .padding()
    }
}

#Preview {
    OnboardingView()
}
