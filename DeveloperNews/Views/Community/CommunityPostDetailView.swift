import SwiftUI

struct CommunityPostDetailView: View {
    private let appState: AppState
    private let post: CommunityPost

    @State private var showEditPost = false
    @State private var showDeleteConfirm = false
    @State private var showReportConfirm = false
    @State private var showBlockConfirm = false
    @State private var showOtherReasonInput = false
    @State private var otherReasonText = ""
    @State private var alreadyReported = false

    @Environment(\.dismiss) private var dismiss

    init(
        appState: AppState,
        post: CommunityPost,
    ) {
        self.appState = appState
        self.post = post
    }

    private var community: CommunityService {
        appState.communityService
    }
    private var currentUserId: String? {
        appState.authService.userId
    }
    private var isAuthor: Bool {
        currentUserId == post.authorId
    }
    private var isLiked: Bool {
        guard let uid = currentUserId else { return false }
        return post.likedBy.contains(uid)
    }
    private var isFollowingAuthor: Bool {
        appState.profileService.isFollowing(currentPost.authorId)
    }
    private var authorEmoji: String? {
        community.authorEmoji(for: currentPost.authorId)
    }

    private var currentPost: CommunityPost {
        community.posts.first { $0.id == post.id } ?? post
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(currentPost.title)
                    .font(.title2.bold())
                HStack(spacing: 8) {
                    NavigationLink {
                        UserProfileView(
                            appState: appState,
                            authorId: currentPost.authorId,
                            authorName: currentPost.authorName,
                            authorEmoji: authorEmoji)
                    } label: {
                        HStack(spacing: 4) {
                            if let authorEmoji {
                                Text(authorEmoji)
                            }
                            Text(currentPost.authorName)
                                .font(.caption.weight(.semibold))
                                .underline()
                        }
                    }
                    .buttonStyle(.plain)

                    if !isAuthor,
                       currentUserId != nil {
                        Button(action: toggleFollow) {
                            Text(isFollowingAuthor ? .communityFollowing : .communityFollow)
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    isFollowingAuthor
                                        ? Color.accentColor
                                        : Color(.secondarySystemBackground))
                                .foregroundStyle(
                                    isFollowingAuthor
                                        ? Color.white
                                        : Color.primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(currentPost.createdAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !currentPost.topics.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(currentPost.topics) { topic in
                            Label {
                                Text(topic.title)
                            } icon: {
                                Image(systemName: topic.symbolName)
                            }
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background {
                                Color(.secondarySystemBackground)
                            }
                            .clipShape(Capsule())
                        }
                    }
                }

                if !currentPost.description.isEmpty {
                    Divider()
                    Text(currentPost.description)
                        .font(.body)
                }

                if currentPost.hasLink,
                   let url = currentPost.linkURL {
                    Divider()
                    let linkItem = ContentItem(
                        id: UUID(),
                        kind: .article,
                        title: currentPost.title,
                        summary: "",
                        sourceName: currentPost.authorName,
                        sourceCategory: .article,
                        authorName: currentPost.authorName,
                        url: url,
                        publishedAt: currentPost.createdAt,
                        topics: currentPost.topics,
                        trendScore: 0)
                    NavigationLink {
                        ArticleDetailView(appState: appState, item: linkItem)
                    } label: {
                        HStack {
                            Label(.bookmarkOpenLink, systemImage: "safari")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background {
                            Color(.secondarySystemBackground)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(.communityCreatedAt)
                        Text(currentPost.createdAt, style: .date)
                        Text(currentPost.createdAt, style: .time)
                    }
                    if let updatedAt = currentPost.updatedAt {
                        HStack(spacing: 4) {
                            Text(.communityUpdatedAt)
                            Text(updatedAt, style: .date)
                            Text(updatedAt, style: .time)
                        }
                    }
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
                HStack {
                    Button(action: toggleLike) {
                        HStack(spacing: 4) {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .foregroundStyle(isLiked ? .red : .secondary)
                            Text("\(currentPost.likeCount)")
                        }
                        .font(.subheadline)
                    }
                    .buttonStyle(.plain)
                    .disabled(currentUserId == nil)
                    Spacer()
                }

                if isAuthor {
                    Button(
                        .communityDeletePost,
                        role: .destructive,
                        action: confirmDelete)
                        .font(.footnote)
                }
                else if currentUserId != nil {
                    HStack(spacing: 16) {
                        Button(.communityReport, action: confirmReport)
                            .disabled(alreadyReported)
                            .foregroundStyle(alreadyReported ? Color.secondary : Color.red)
                        Button(.communityBlockUser, action: confirmBlockUser)
                            .foregroundStyle(.red)
                    }
                    .font(.footnote)

                    if alreadyReported {
                        Text(.communityAlreadyReported)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(20)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            if isAuthor {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: openEditPost) {
                        Image(systemName: "pencil")
                    }
                    .accessibilityLabel(.communityEditPost)
                }
            }
        }
        .onAppear(perform: onAppear)
        .alert(.communityReportReasonOtherTitle, isPresented: $showOtherReasonInput) {
            TextField(.communityReportReasonOtherPlaceholder, text: $otherReasonText)
                .keenOnChange(of: otherReasonText, perform: onOtherReasonTextChange)
            Button(
                "Cancel",
                role: .cancel) {}
            Button(.communityReport, action: submitOtherReport)
        } message: {
            Text(.communityReportReasonOtherMessage)
        }
        .dialog(
            .communityDeleteConfirm,
            isPresented: $showDeleteConfirm,
            buttons: communityDeleteConfirmDialogView)
        .dialog(
            .communityReportConfirmTitle,
            isPresented: $showReportConfirm,
            buttons: communityReportConfirmDialogView)
        .dialog(
            .communityBlockConfirmTitle,
            message: .communityBlockConfirmMessage,
            isPresented: $showBlockConfirm,
            buttons: communityBlockConfirmDialogView)
        .sheet(isPresented: $showEditPost) {
            EditCommunityPostView(
                appState: appState,
                post: currentPost)
        }
    }

    private var communityDeleteConfirmDialogView: some View {
        Button(
            "Delete",
            role: .destructive,
            action: deletePost)
    }

    @ViewBuilder
    private var communityReportConfirmDialogView: some View {
        Button(.communityReportReasonSpam, action: reportSpam)
        Button(.communityReportReasonInappropriate, action: reportInappropriate)
        Button(.communityReportReasonOther, action: openOtherReasonInput)
    }

    private var communityBlockConfirmDialogView: some View {
        Button(
            .communityBlockConfirmAction,
            role: .destructive,
            action: blockUser)
    }

    private func onAppear() {
        appState.markPostAsRead(post.id)
        appState.markURLAsRead("devnews://community/\(post.id)")
        Task {
            guard let uid = currentUserId else { return }
            alreadyReported = await community.hasReportedPost(post.id, reporterId: uid)
        }
    }

    private func onOtherReasonTextChange(_ new: String) {
        if new.count > 200 {
            otherReasonText = String(new.prefix(200))
        }
    }

    private func toggleFollow() {
        Task {
            await appState.profileService.toggleFollow(currentPost.authorId)
        }
    }

    private func toggleLike() {
        guard let uid = currentUserId else { return }
        Task {
            await community.toggleLike(currentPost, userId: uid)
        }
    }

    private func confirmDelete() {
        showDeleteConfirm = true
    }

    private func confirmReport() {
        showReportConfirm = true
    }

    private func confirmBlockUser() {
        showBlockConfirm = true
    }

    private func openEditPost() {
        showEditPost = true
    }

    private func deletePost() {
        Task {
            await community.deletePost(currentPost)
            dismiss()
        }
    }

    private func reportSpam() {
        submitReport("spam")
    }

    private func reportInappropriate() {
        submitReport("inappropriate")
    }

    private func openOtherReasonInput() {
        otherReasonText = ""
        showOtherReasonInput = true
    }

    private func submitOtherReport() {
        let trimmed = otherReasonText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        submitReport("other: \(trimmed)")
    }

    private func blockUser() {
        appState.blockUser(currentPost.authorId)
        dismiss()
    }

    private func submitReport(_ reason: String) {
        guard let uid = currentUserId else { return }
        Task {
            await community.reportPost(currentPost, reporterId: uid, reason: reason)
            alreadyReported = true
        }
    }
}

