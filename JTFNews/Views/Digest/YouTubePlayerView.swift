import SwiftUI
import WebKit

struct YouTubePlayerView: UIViewRepresentable {
    let videoURL: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard let videoID = extractVideoID(from: videoURL) else { return }

        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <style>
        * { margin: 0; padding: 0; }
        body { background: #000; overflow: hidden; }
        iframe { width: 100%; height: 100%; position: absolute; top: 0; left: 0; }
        </style>
        </head>
        <body>
        <iframe
            src="https://www.youtube.com/embed/\(videoID)?playsinline=1&rel=0&modestbranding=1"
            frameborder="0"
            allowfullscreen
            allow="autoplay; encrypted-media">
        </iframe>
        </body>
        </html>
        """

        webView.loadHTMLString(html, baseURL: nil)
    }

    private func extractVideoID(from url: String) -> String? {
        if url.contains("youtube.com/embed/") {
            return url.components(separatedBy: "embed/").last?.components(separatedBy: "?").first
        }
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

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard let url = navigationAction.request.url else { return .allow }
            let urlString = url.absoluteString

            // Allow the initial HTML load and YouTube embed iframe
            if navigationAction.navigationType == .other {
                return .allow
            }

            // Allow YouTube embed URLs within the iframe
            if urlString.contains("youtube.com/embed") {
                return .allow
            }

            // Open all other URLs (Watch on YouTube, etc.) in Safari
            await MainActor.run {
                UIApplication.shared.open(url)
            }
            return .cancel
        }
    }
}
