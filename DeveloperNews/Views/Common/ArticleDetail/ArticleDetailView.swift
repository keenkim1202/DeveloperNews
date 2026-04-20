import SwiftUI
import WebKit
import Translation

struct ArticleDetailView: View {
    private let appState: AppState
    private let item: ContentItem

    @State private var isLoading = true
    @State private var loadError: String?
    @State private var loadProgress: Double = 0
    @State private var reloadTrigger = 0
    @State private var webViewRef: WKWebView?
    @State private var pageTranslationTrigger = 0
    @State private var isTranslatingPage = false
    @State private var isPageTranslated = false
    @State private var showEditNote = false

    init(
        appState: AppState,
        item: ContentItem,
    ) {
        self.appState = appState
        self.item = item
    }

    private var translator: ContentTranslator {
        appState.translator
    }

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
                    Label(.couldNotLoadArticle, systemImage: "wifi.exclamationmark")
                } description: {
                    Text(message)
                } actions: {
                    Button(action: retryLoad) {
                        Text(.tryAgain)
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)

                    ShareLink(item: item.url, subject: Text(item.title)) {
                        Text(.openElsewhere)
                    }
                }
                .background {
                    Color(.systemBackground)
                }
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
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: toggleSaved) {
                    Image(systemName: appState.isSaved(item) ? "bookmark.fill" : "bookmark")
                }
                .accessibilityLabel(appState.isSaved(item) ? .removeFromSaved : .saveStory)
            }
            if appState.isSaved(item) {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: openNoteEditor) {
                        Image(systemName: currentNote.isEmpty ? "note.text.badge.plus" : "note.text")
                            .foregroundStyle(currentNote.isEmpty ? Color.primary : Color.accentColor)
                    }
                }
            }
            if translator.canTranslate {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: togglePageTranslation) {
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
                    .accessibilityLabel(.translatePage)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: reload) {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoading)
                .accessibilityLabel(.reloadArticle)
            }
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: item.url, subject: Text(item.title)) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear(perform: onAppear)
        .sheet(isPresented: $showEditNote) { noteEditorSheet }
    }

    private func onAppear() {
        appState.markAsRead(item)
    }

    private func retryLoad() {
        loadError = nil
        reloadTrigger &+= 1
    }

    private func toggleSaved() {
        appState.toggleSaved(item)
    }

    private func openNoteEditor() {
        showEditNote = true
    }

    private func togglePageTranslation() {
        if isPageTranslated {
            restoreOriginalPage()
        }
        else {
            pageTranslationTrigger &+= 1
        }
    }

    private func reload() {
        reloadTrigger &+= 1
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

        guard let jsonString = try? await webView.callAsyncJavaScript(extractJS, contentWorld: .page) as? String,
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
                TranslationSession.Request(
                    sourceText: $0.text,
                    clientIdentifier: String($0.id))
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
