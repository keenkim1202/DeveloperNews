import SwiftUI
import WebKit
import Translation

struct ArticleDetailView: View {
    let appState: AppState
    let item: ContentItem

    private var translator: ContentTranslator { appState.translator }

    @State private var isLoading = true
    @State private var loadError: String?
    @State private var loadProgress: Double = 0
    @State private var reloadTrigger = 0
    @State private var webViewRef: WKWebView?
    @State private var pageTranslationTrigger = 0
    @State private var isTranslatingPage = false
    @State private var isPageTranslated = false
    @State private var showEditNote = false

    var body: some View {
        ZStack(alignment: .top) {
            ArticleWebView(
                url: item.url,
                isLoading: $isLoading,
                loadError: $loadError,
                progress: $loadProgress,
                webViewRef: $webViewRef,
                reloadTrigger: reloadTrigger)
            .opacity(loadError == nil ? 1 : 0)
            .ignoresSafeArea(edges: .bottom)

            if isLoading && loadProgress < 1 {
                ProgressView(value: max(loadProgress, 0.05))
                    .progressViewStyle(.linear)
                    .tint(.accentColor)
                    .frame(height: 2)
                    .transition(.opacity)
            }

            if let message = loadError {
                ContentUnavailableView {
                    Label("Could not load article", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(message)
                } actions: {
                    Button {
                        loadError = nil
                        reloadTrigger &+= 1
                    } label: {
                        Text("Try again")
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)

                    ShareLink(item: item.url, subject: Text(item.title)) {
                        Text("Open elsewhere")
                    }
                }
                .background(Color(.systemBackground))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isLoading)
        .overlay {
            if let config = translator.makeConfiguration(), pageTranslationTrigger > 0 {
                Color.clear
                    .id(pageTranslationTrigger)
                    .translationTask(config) { session in
                        await translateWebPage(using: session)
                    }
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text(translator.title(for: item))
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(item.sourceName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    appState.toggleSaved(item)
                } label: {
                    Image(systemName: appState.isSaved(item) ? "bookmark.fill" : "bookmark")
                }
                .accessibilityLabel(appState.isSaved(item) ? "Remove from saved" : "Save story")
            }

            if appState.isSaved(item) {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showEditNote = true
                    } label: {
                        Image(systemName: currentNote.isEmpty ? "note.text.badge.plus" : "note.text")
                            .foregroundStyle(currentNote.isEmpty ? Color.primary : Color.accentColor)
                    }
                }
            }

            if translator.canTranslate {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if isPageTranslated {
                            restoreOriginalPage()
                        }
                        else {
                            pageTranslationTrigger &+= 1
                        }
                    } label: {
                        if isTranslatingPage {
                            ProgressView()
                                .controlSize(.small)
                        }
                        else {
                            Image(systemName: "translate")
                                .foregroundStyle(isPageTranslated ? Color.accentColor : Color.primary)
                        }
                    }
                    .disabled(isLoading || isTranslatingPage)
                    .accessibilityLabel("Translate page")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    reloadTrigger &+= 1
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoading)
                .accessibilityLabel("Reload article")
            }

            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: item.url, subject: Text(item.title)) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            appState.markAsRead(item)
        }
        .sheet(isPresented: $showEditNote) { noteEditorSheet }
    }

    private var currentNote: String {
        appState.savedItemSnapshots[item.url]?.summary ?? ""
    }

    @ViewBuilder
    private var noteEditorSheet: some View {
        SavedItemNoteComposerView(appState: appState, item: appState.savedItemSnapshots[item.url] ?? item)
    }

    private func translateWebPage(using session: TranslationSession) async {
        guard let webView = webViewRef else { return }
        isTranslatingPage = true

        let extractJS = """
        var els=document.querySelectorAll('p,h1,h2,h3,h4,h5,h6,li,td,th,blockquote,figcaption,dt,dd');
        var r=[];
        for(var i=0;i<els.length;i++){
            var t=els[i].innerText.trim();
            if(t.length>0&&t.length<5000){
                els[i].setAttribute('data-tr-id',String(i));
                els[i].setAttribute('data-tr-orig',els[i].innerText);
                r.push({id:i,text:t});
            }
        }
        return JSON.stringify(r);
        """

        guard let jsonString = try? await webView.callAsyncJavaScript(
            extractJS, contentWorld: .page
        ) as? String,
              let data = jsonString.data(using: .utf8),
              let entries = try? JSONDecoder().decode([PageTextEntry].self, from: data),
              !entries.isEmpty
        else {
            isTranslatingPage = false
            return
        }

        let chunkSize = 15
        for chunkStart in stride(from: 0, to: entries.count, by: chunkSize) {
            let chunkEnd = min(chunkStart + chunkSize, entries.count)
            let chunk = Array(entries[chunkStart..<chunkEnd])
            let requests = chunk.map {
                TranslationSession.Request(sourceText: $0.text, clientIdentifier: String($0.id))
            }

            var translations: [String: String] = [:]
            do {
                for try await response in session.translate(batch: requests) {
                    if let id = response.clientIdentifier {
                        translations[id] = response.targetText
                    }
                }
            }
            catch {
                continue
            }

            guard !translations.isEmpty else { continue }

            let injectJS = """
            for(var id in translations){
                var el=document.querySelector('[data-tr-id="'+id+'"]');
                if(el) el.innerText=translations[id];
            }
            """
            _ = try? await webView.callAsyncJavaScript(
                injectJS,
                arguments: ["translations": translations],
                contentWorld: .page)
        }

        isTranslatingPage = false
        isPageTranslated = true
    }

    private func restoreOriginalPage() {
        guard let webView = webViewRef else { return }

        let restoreJS = """
        var els=document.querySelectorAll('[data-tr-orig]');
        for(var i=0;i<els.length;i++){
            els[i].innerText=els[i].getAttribute('data-tr-orig');
        }
        """
        webView.evaluateJavaScript(restoreJS)
        isPageTranslated = false
    }
}


struct ArticleWebView: UIViewRepresentable {
    let url: URL
    let isLoading: Binding<Bool>
    let loadError: Binding<String?>
    let progress: Binding<Double>
    let webViewRef: Binding<WKWebView?>
    let reloadTrigger: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.addObserver(context.coordinator, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
        context.coordinator.observedWebView = webView
        DispatchQueue.main.async {
            self.webViewRef.wrappedValue = webView
        }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
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

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        if let observed = coordinator.observedWebView {
            observed.removeObserver(coordinator, forKeyPath: #keyPath(WKWebView.estimatedProgress))
            coordinator.observedWebView = nil
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let parent: ArticleWebView
        var loadedURL: URL?
        var lastReloadTrigger: Int
        weak var observedWebView: WKWebView?

        init(parent: ArticleWebView) {
            self.parent = parent
            self.lastReloadTrigger = parent.reloadTrigger
        }

        override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
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

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading.wrappedValue = true
                self.parent.loadError.wrappedValue = nil
                self.parent.progress.wrappedValue = 0
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading.wrappedValue = false
                self.parent.progress.wrappedValue = 1
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading.wrappedValue = false
                self.parent.loadError.wrappedValue = error.localizedDescription
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading.wrappedValue = false
                self.parent.loadError.wrappedValue = error.localizedDescription
            }
        }
    }
}


struct PageTextEntry: Decodable {
    let id: Int
    let text: String
}

