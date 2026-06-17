import SwiftUI
import WebKit
import Translation

struct ArticleDetailView: View {
    @State private var viewModel: ArticleDetailViewModel
    @State private var engagementViewModel: StoryEngagementViewModel
    private let appState: AppState
    private let item: ContentItem

    @State private var isLoading = true
    @State private var loadError: String?
    @State private var loadProgress: Double = 0
    @State private var reloadTrigger = 0
    @State private var webViewRef: WKWebView?
    @State private var pageTranslationTrigger = 0
    @State private var showEditNote = false
    @State private var showPostComposer = false
    @State private var showComments = false

    init(
        appState: AppState,
        item: ContentItem,
    ) {
        _viewModel = State(initialValue: ArticleDetailViewModel(
            appState: appState,
            item: item))
        _engagementViewModel = State(initialValue: StoryEngagementViewModel(
            appState: appState,
            storyURL: item.url.absoluteString))
        self.appState = appState
        self.item = item
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
                    .tint(DSColor.accent)
                    .frame(height: 2)
                    .transition(.opacity)
            }

            if let message = loadError {
                ContentUnavailableView {
                    Label(.couldNotLoadArticle, icon: .networkError)
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
                    DSColor.background
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isLoading)
        .overlay {
            if let config = viewModel.makeTranslationConfiguration(), pageTranslationTrigger > 0 {
                Color.clear
                    .id(pageTranslationTrigger)
                    .translationTask(config) { session in
                        await translateWebPage(using: session)
                    }
            }
        }
        .toolbar {
            if viewModel.isSaved {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: openNoteEditor) {
                        Image(viewModel.currentNote.isEmpty ? .noteAdd : .note)
                            .foregroundStyle(viewModel.currentNote.isEmpty ? Color.primary : DSColor.accent)
                    }
                }
            }
            if viewModel.canTranslate {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: togglePageTranslation) {
                        if viewModel.isTranslatingPage {
                            ProgressView()
                                .controlSize(.small)
                        }
                        else {
                            Image(.translate)
                                .foregroundStyle(viewModel.isPageTranslated ? DSColor.accent : Color.primary)
                        }
                    }
                    .disabled(isLoading || viewModel.isTranslatingPage)
                    .accessibilityLabel(.translatePage)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: reload) {
                    Image(.refresh)
                }
                .disabled(isLoading)
                .accessibilityLabel(.reloadArticle)
            }
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: item.url, subject: Text(item.title)) {
                    Image(.share)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            storyActionBar
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear(perform: onAppear)
        .onDisappear(perform: onDisappear)
        .sheet(isPresented: $showEditNote) { noteEditorSheet }
        .sheet(isPresented: $showPostComposer) { postComposerSheet }
        .sheet(isPresented: $showComments) { commentsSheet }
    }

    private var storyActionBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 0) {
                Button(action: toggleLike) {
                    actionLabel(
                        icon: engagementViewModel.isLiked ? .likeFilled : .like,
                        count: engagementViewModel.likeCount,
                        tint: engagementViewModel.isLiked ? .red : .primary)
                }
                .buttonStyle(.plain)
                .disabled(engagementViewModel.currentUserId == nil)
                .frame(maxWidth: .infinity)
                Button(action: openComments) {
                    actionLabel(
                        icon: .comment,
                        count: engagementViewModel.commentCount,
                        tint: .primary)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                Button(action: toggleSaved) {
                    actionLabel(
                        icon: viewModel.isSaved ? .bookmarkFilled : .bookmark,
                        count: nil,
                        tint: viewModel.isSaved ? DSColor.accent : .primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(viewModel.isSaved ? .removeFromSaved : .saveStory)
                .frame(maxWidth: .infinity)
                Button(action: openPostComposer) {
                    actionLabel(
                        icon: .quote,
                        count: nil,
                        tint: .primary)
                }
                .buttonStyle(.plain)
                .disabled(engagementViewModel.currentUserId == nil)
                .accessibilityLabel(.feedPostShareAsPost)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background {
            DSColor.background
        }
    }

    private func actionLabel(
        icon: DSIcon,
        count: Int?,
        tint: Color,
    ) -> some View {
        HStack(spacing: 6) {
            Image(icon)
                .foregroundStyle(tint)
            if let count {
                Text("\(count)")
                    .foregroundStyle(.primary)
            }
        }
        .font(.subheadline)
    }

    @ViewBuilder
    private var commentsSheet: some View {
        StoryCommentsSheet(viewModel: engagementViewModel)
    }

    private func onAppear() {
        viewModel.markAsRead()
        Task {
            await engagementViewModel.startListening()
        }
    }

    private func onDisappear() {
        engagementViewModel.stopListening()
    }

    private func toggleLike() {
        Task {
            await engagementViewModel.toggleLike()
        }
    }

    private func openComments() {
        showComments = true
    }

    private func retryLoad() {
        loadError = nil
        reloadTrigger &+= 1
    }

    private func toggleSaved() {
        viewModel.toggleSaved()
    }

    private func openNoteEditor() {
        showEditNote = true
    }

    private func openPostComposer() {
        showPostComposer = true
    }

    private func togglePageTranslation() {
        if viewModel.isPageTranslated {
            restoreOriginalPage()
        }
        else {
            pageTranslationTrigger &+= 1
        }
    }

    private func reload() {
        reloadTrigger &+= 1
    }

    @ViewBuilder
    private var noteEditorSheet: some View {
        SavedItemNoteComposerView(appState: appState, item: viewModel.noteEditorItem)
    }

    @ViewBuilder
    private var postComposerSheet: some View {
        FeedPostComposerView(appState: appState, item: item)
    }

    private func translateWebPage(using session: TranslationSession) async {
        guard let webView = webViewRef else { return }
        viewModel.isTranslatingPage = true

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
            viewModel.isTranslatingPage = false
            return
        }

        let chunkSize = 15
        for chunkStart in stride(from: 0, to: entries.count, by: chunkSize) {
            let chunkEnd = min(chunkStart + chunkSize, entries.count)
            let chunk = Array(entries[chunkStart..<chunkEnd])
            let translations = await viewModel.translateChunk(chunk, using: session)

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

        viewModel.isTranslatingPage = false
        viewModel.isPageTranslated = true
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
        viewModel.isPageTranslated = false
    }
}
