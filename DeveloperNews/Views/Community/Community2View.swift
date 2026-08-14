import SwiftUI

struct Community2View: View {
    private let appState: AppState

    @Bindable private var viewModel: Community2ViewModel
    @Bindable private var navigation: Navigation

    init(
        appState: AppState,
        viewModel: Community2ViewModel,
        navigation: Navigation,
    ) {
        self.appState = appState
        self.viewModel = viewModel
        self.navigation = navigation
    }

    var body: some View {
        NavigationStack(path: $navigation.community) {
            VStack(spacing: 0) {
                tabPicker
                tabContent
            }
            .navigationTitle(.community)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: openActivity) {
                        activityBell
                    }
                    .accessibilityLabel(Text(.activityTitle))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: openUserSearch) {
                        Image(systemName: "magnifyingglass")
                    }
                }
            }
            .navigationDestination(for: CommunityTabDestination.self, destination: destination)
            .keenOnChange(of: viewModel.tab, perform: onTabChange)
            .onAppear(perform: onAppear)
        }
    }

    // `.badge` is only honored on list rows and tab items, so the unread mark
    // on a toolbar button has to be drawn.
    private var activityBell: some View {
        Image(systemName: "bell")
            .overlay(alignment: .topTrailing) {
                if appState.unreadActivityCount > 0 {
                    Circle()
                        .fill(DSColor.destructive)
                        .frame(width: 8, height: 8)
                        .offset(x: 4, y: -3)
                }
            }
    }

    private var tabPicker: some View {
        Picker(.community, selection: $viewModel.tab) {
            Text(.communityDiscover).tag(Community2ViewModel.Tab.discover)
            Text(.communityFollowing).tag(Community2ViewModel.Tab.following)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch viewModel.tab {
        case .discover:
            VStack(spacing: 0) {
                modePicker
                discoverContent
            }
        case .following:
            followingContent
        }
    }

    private var modePicker: some View {
        Picker(.community, selection: $viewModel.mode) {
            Text(.discoverTrending).tag(Community2ViewModel.Mode.trending)
            Text(.discoverRecent).tag(Community2ViewModel.Mode.recent)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var discoverContent: some View {
        if viewModel.isLoading && viewModel.hasNoPosts {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        else if viewModel.hasNoPosts {
            refreshableEmptyState(refresh: refresh) {
                ContentUnavailableView {
                    Label(.discoverEmpty, icon: .community)
                } description: {
                    Text(.discoverEmptyDescription)
                }
            }
        }
        else {
            feedList(viewModel.displayedPosts, refresh: refresh)
        }
    }

    @ViewBuilder
    private var followingContent: some View {
        if !viewModel.isSignedIn {
            ContentUnavailableView {
                Label(.followingSignIn, icon: .account)
            } description: {
                Text(.followingSignInDescription)
            }
        }
        else if viewModel.isLoadingFollowing && viewModel.hasNoFollowingPosts {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        else if viewModel.hasNoFollowingPosts {
            refreshableEmptyState(refresh: refreshFollowing) {
                ContentUnavailableView {
                    Label(.followingEmpty, icon: .community)
                } description: {
                    Text(.followingEmptyDescription)
                }
            }
        }
        else {
            feedList(viewModel.visibleFollowingPosts, refresh: refreshFollowing)
        }
    }

    private func feedList(
        _ posts: [FeedPost],
        refresh: @escaping @Sendable () async -> Void,
    ) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(posts) { post in
                    FeedPostRow(
                        post: post,
                        currentUserId: appState.authService.userId,
                        onTap: { navigateToDetail(post) },
                        onAuthorTap: { navigateToProfile(post) },
                        onLike: { toggleLike(post) })
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    Divider()
                }
            }
        }
        .refreshable(action: refresh)
    }

    // Empty-state content has no scrollable list to host pull-to-refresh, so
    // wrap it in a viewport-filling ScrollView that can still be pulled down.
    private func refreshableEmptyState(
        refresh: @escaping @Sendable () async -> Void,
        @ViewBuilder content: () -> some View,
    ) -> some View {
        ScrollView {
            content()
                .frame(maxWidth: .infinity)
                .containerRelativeFrame(.vertical)
        }
        .refreshable(action: refresh)
    }

    @ViewBuilder
    private func destination(_ dest: CommunityTabDestination) -> some View {
        switch dest {
        case let .userProfile(userId):
            UserProfileView(appState: appState, authorId: userId)
        case let .storyDetail(story):
            if let item = story.contentItem {
                ArticleDetailView(appState: appState, item: item)
            }
            else {
                UnavailableDestinationView(reason: .itemNotFound)
            }
        case let .feedPostDetail(postId):
            FeedPostDetailView(appState: appState, postId: postId)
        case let .postDetail(postId):
            if let post = appState.communityService.post(id: postId) {
                CommunityPostDetailView(appState: appState, post: post)
            }
            else {
                UnavailableDestinationView(reason: .postDeleted)
            }
        case let .postLinkDetail(postId):
            if let post = appState.communityService.post(id: postId),
               let item = post.linkContentItem {
                ArticleDetailView(appState: appState, item: item)
            }
            else {
                UnavailableDestinationView(reason: .itemNotFound)
            }
        case let .followList(target):
            FollowListView(
                appState: appState,
                userId: target.userId,
                kind: target.kind)
        case .userSearch:
            UserSearchView(appState: appState)
        case .activity:
            ActivityView(appState: appState)
        }
    }

    private func openUserSearch() {
        navigation(.community(.userSearch))
    }

    private func openActivity() {
        navigation(.community(.activity))
    }

    private func navigateToDetail(_ post: FeedPost) {
        navigation(.community(.feedPostDetail(post.id)))
    }

    private func navigateToProfile(_ post: FeedPost) {
        navigation(.community(.userProfile(userId: post.authorId)))
    }

    private func toggleLike(_ post: FeedPost) {
        Task {
            await viewModel.toggleLike(post)
        }
    }

    private func onAppear() {
        Task {
            await viewModel.loadIfNeeded()
        }
    }

    private func onTabChange(_ tab: Community2ViewModel.Tab) {
        guard tab == .following, viewModel.isSignedIn, !viewModel.hasLoadedFollowing else {
            return
        }
        Task {
            await viewModel.loadFollowing()
        }
    }

    private func refresh() async {
        await viewModel.load()
    }

    private func refreshFollowing() async {
        await viewModel.loadFollowing()
    }
}
