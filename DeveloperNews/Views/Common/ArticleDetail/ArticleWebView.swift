import SwiftUI
import WebKit

struct ArticleWebView: UIViewRepresentable {
    private let url: URL
    private let isLoading: Binding<Bool>
    private let loadError: Binding<String?>
    private let progress: Binding<Double>
    private let webViewRef: Binding<WKWebView?>
    private let reloadTrigger: Int

    init(
        url: URL,
        isLoading: Binding<Bool>,
        loadError: Binding<String?>,
        progress: Binding<Double>,
        webViewRef: Binding<WKWebView?>,
        reloadTrigger: Int,
    ) {
        self.url = url
        self.isLoading = isLoading
        self.loadError = loadError
        self.progress = progress
        self.webViewRef = webViewRef
        self.reloadTrigger = reloadTrigger
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.addObserver(
            context.coordinator,
            forKeyPath: #keyPath(WKWebView.estimatedProgress),
            options: .new, context: nil)
        context.coordinator.observedWebView = webView
        DispatchQueue.main.async {
            self.webViewRef.wrappedValue = webView
        }
        return webView
    }

    func updateUIView(
        _ webView: WKWebView,
        context: Context,
    ) {
        if context.coordinator.loadedURL != url {
            context.coordinator.loadedURL = url
            context.coordinator.lastReloadTrigger = reloadTrigger
            webView.load(URLRequest(url: url))
        }
        else if context.coordinator.lastReloadTrigger != reloadTrigger {
            context.coordinator.lastReloadTrigger = reloadTrigger
            webView.reload()
        }
    }

    static func dismantleUIView(
        _ webView: WKWebView,
        coordinator: Coordinator,
    ) {
        if let observed = coordinator.observedWebView {
            observed.removeObserver(
                coordinator,
                forKeyPath: #keyPath(WKWebView.estimatedProgress))
            coordinator.observedWebView = nil
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let parent: ArticleWebView
        fileprivate var loadedURL: URL?
        fileprivate var lastReloadTrigger: Int
        fileprivate weak var observedWebView: WKWebView?

        init(parent: ArticleWebView) {
            self.parent = parent
            self.lastReloadTrigger = parent.reloadTrigger
        }

        override func observeValue(
            forKeyPath keyPath: String?,
            of object: Any?,
            change: [NSKeyValueChangeKey: Any]?,
            context: UnsafeMutableRawPointer?,
        ) {
            guard
                keyPath == #keyPath(WKWebView.estimatedProgress),
                let webView = object as? WKWebView
            else {
                return
            }
            let value = webView.estimatedProgress
            DispatchQueue.main.async {
                self.parent.progress.wrappedValue = value
            }
        }

        func webView(
            _ webView: WKWebView,
            didStartProvisionalNavigation navigation: WKNavigation!,
        ) {
            DispatchQueue.main.async {
                self.parent.isLoading.wrappedValue = true
                self.parent.loadError.wrappedValue = nil
                self.parent.progress.wrappedValue = 0
            }
        }

        func webView(
            _ webView: WKWebView,
            didFinish navigation: WKNavigation!,
        ) {
            DispatchQueue.main.async {
                self.parent.isLoading.wrappedValue = false
                self.parent.progress.wrappedValue = 1
            }
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: Error,
        ) {
            DispatchQueue.main.async {
                self.parent.isLoading.wrappedValue = false
                self.parent.loadError.wrappedValue = error.localizedDescription
            }
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error,
        ) {
            DispatchQueue.main.async {
                self.parent.isLoading.wrappedValue = false
                self.parent.loadError.wrappedValue = error.localizedDescription
            }
        }
    }
}
