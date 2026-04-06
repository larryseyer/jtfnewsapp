import SwiftUI
import WebKit

struct YouTubePlayerView: UIViewRepresentable {
    let videoURL: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard let url = URL(string: embedURL) else { return }
        let request = URLRequest(url: url)
        webView.load(request)
    }

    private var embedURL: String {
        if videoURL.contains("youtube.com/embed/") {
            return videoURL
        }
        if let videoID = extractVideoID(from: videoURL) {
            return "https://www.youtube.com/embed/\(videoID)"
        }
        return videoURL
    }

    private func extractVideoID(from url: String) -> String? {
        if let range = url.range(of: "v=") {
            let start = range.upperBound
            let end = url[start...].firstIndex(of: "&") ?? url.endIndex
            return String(url[start..<end])
        }
        if url.contains("youtu.be/") {
            return url.components(separatedBy: "youtu.be/").last?.components(separatedBy: "?").first
        }
        return nil
    }
}
