import SwiftUI

struct FeedPostDetailView: View {
    private let appState: AppState

    @State private var viewModel: FeedPostDetailViewModel

    @State private var showReportConfirm = false
    @State private var showBlockConfirm = false
    @State private var showOtherReasonInput = false
    @State private var otherReasonText = ""
    @State private var pendingReason: ReportReason?
    @State private var commentText = ""
    @State private var shouldScrollToLatestComment = false
    @State private var commentPendingDeletion: CommunityComment?
    @State private var showDeleteCommentConfirm = false
    @FocusState private var commentFieldFocused: Bool

    @Environment(\.dismiss) private var dismiss

    init(
        appState: AppState,
        post: FeedPost,
    ) {
        self.appState = appState
        _viewModel = State(initialValue: FeedPostDetailViewModel(
            appState: appState,
            post: post))
    }

    private var currentUserId: String? {
        viewModel.currentUserId
    }
    private var isAuthor: Bool {
        viewModel.isAuthor
    }
    private var isLiked: Bool {
        viewModel.isLiked
    }
    private var currentPost: FeedPost {
        viewModel.currentPost
    }
    private var visibleComments: [CommunityComment] {
        viewModel.visibleComments
    }
    private var canSubmitComment: Bool {
        viewModel.canSubmitComment(commentText: commentText)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    postHeader
                    if !currentPost.comment.isEmpty {
                        Text(currentPost.comment)
                            .font(.body)
                    }
                    storyCard
                    engagementBar
                    Divider()
                    commentsSection
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(TapGesture().onEnded(dismissKeyboard))
            .keenOnChange(of: visibleComments.count) {
                scrollToLatestComment(proxy)
            }
            .safeAreaInset(edge: .bottom) {
                if currentUserId != nil {
                    commentInputBar
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
            .toolbar {
                if !isAuthor, currentUserId != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        moderationMenu
                    }
                }
            }
            .onAppear(perform: onAppear)
            .onDisappear(perform: onDisappear)
            .alert(.communityReportReasonOtherTitle, isPresented: $showOtherReasonInput) {
                TextField(.communityReportReasonOtherPlaceholder, text: $otherReasonText)
                    .keenOnChange(of: otherReasonText, perform: onOtherReasonTextChange)
                Button("Cancel", role: .cancel) {}
                Button(.communityReport, action: submitOtherReport)
            } message: {
                Text(.communityReportReasonOtherMessage)
            }
            .alert(
                .communityReportConfirmTitle,
                isPresented: $showReportConfirm) {
                Button("Cancel", role: .cancel) {}
                Button(
                    .communityReport,
                    role: .destructive,
                    action: submitPendingReport)
            }
            .alert(
                .communityBlockConfirmTitle,
                isPresented: $showBlockConfirm) {
                Button("Cancel", role: .cancel) {}
                Button(
                    .communityBlockConfirmAction,
                    role: .destructive,
                    action: blockUser)
            } message: {
                Text(.communityBlockConfirmMessage)
            }
            .alert(
                .communityDeleteCommentConfirm,
                isPresented: $showDeleteCommentConfirm) {
                Button("Cancel", role: .cancel) {}
                Button(
                    "Delete",
                    role: .destructive,
                    action: deleteConfirmedComment)
            }
        }
    }

    private var moderationMenu: some View {
        Menu {
            Menu {
                Button(.communityReportReasonSpam, action: reportSpam)
                Button(.communityReportReasonInappropriate, action: reportInappropriate)
                Button(.communityReportReasonOther, action: openOtherReasonInput)
            } label: {
                Label(.communityReport, systemImage: "exclamationmark.bubble")
            }
            Button(
                .communityBlockUser,
                role: .destructive,
                action: confirmBlockUser)
        } label: {
            Image(.more)
        }
    }

    private var postHeader: some View {
        HStack(spacing: 8) {
            NavigationLink(
                value: CommunityTabDestination.userProfile(
                    AuthorInfo(
                        id: currentPost.authorId,
                        name: currentPost.authorName,
                        emoji: currentPost.authorEmoji))) {
                HStack(spacing: 4) {
                    if let emoji = currentPost.authorEmoji {
                        Text(emoji)
                    }
                    Text(currentPost.authorName)
                        .font(.dsLabel)
                        .underline()
                }
            }
            .buttonStyle(.plain)
            Text("·")
                .foregroundStyle(.tertiary)
            Text(currentPost.createdAt, style: .date)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var storyCard: some View {
        NavigationLink(value: CommunityTabDestination.storyDetail(currentPost.story)) {
            HStack(alignment: .top, spacing: 12) {
                if let thumbnailURL = currentPost.story.thumbnailURL.flatMap(URL.init(string:)) {
                    StoryCardThumbnail(url: thumbnailURL)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(currentPost.story.title)
                        .font(.dsCardTitle)
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                    Text(currentPost.story.sourceName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(.chevronForward)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background {
                DSColor.surface
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var engagementBar: some View {
        HStack(spacing: 16) {
            Button(action: toggleLike) {
                HStack(spacing: 4) {
                    Image(isLiked ? .likeFilled : .like)
                        .foregroundStyle(isLiked ? .red : .secondary)
                    Text("\(currentPost.likeCount)")
                }
                .font(.subheadline)
            }
            .buttonStyle(.plain)
            .disabled(currentUserId == nil)
            HStack(spacing: 4) {
                Image(.comment)
                Text("\(currentPost.commentCount)")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(.communityComments)
                .font(.headline)

            if visibleComments.isEmpty {
                Text(.communityCommentsEmpty)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            else {
                ForEach(visibleComments) { comment in
                    commentRow(comment)
                        .id(comment.id)
                }
            }
        }
    }

    private var commentInputBar: some View {
        VStack(spacing: 0) {
            Divider()
            if let error = viewModel.commentErrorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(DSColor.destructive)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }
            HStack(alignment: .bottom, spacing: 8) {
                TextField(
                    .communityCommentPlaceholder,
                    text: $commentText,
                    axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                    .focused($commentFieldFocused)
                Button(action: submitComment) {
                    Image(.sendFilled)
                        .font(.title2)
                }
                .disabled(!canSubmitComment)
                .accessibilityLabel(.communityCommentSubmit)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background {
            DSColor.scrim
        }
    }

    private func commentRow(_ comment: CommunityComment) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                if let emoji = comment.authorEmoji {
                    Text(emoji)
                        .font(.caption)
                }
                Text(comment.authorName)
                    .font(.dsLabel)
                Text("·")
                    .foregroundStyle(.tertiary)
                Text(comment.createdAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(comment.createdAt, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if comment.authorId == currentUserId {
                    Menu {
                        Button(role: .destructive, action: { confirmDeleteComment(comment) }) {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(.more)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            Text(comment.text)
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background {
            DSColor.surface
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func onAppear() {
        viewModel.startListening()
    }

    private func onDisappear() {
        viewModel.stopListening()
    }

    private func dismissKeyboard() {
        commentFieldFocused = false
    }

    private func scrollToLatestComment(_ proxy: ScrollViewProxy) {
        guard shouldScrollToLatestComment,
              let lastId = visibleComments.last?.id
        else { return }
        shouldScrollToLatestComment = false
        withAnimation {
            proxy.scrollTo(lastId, anchor: .bottom)
        }
    }

    private func submitComment() {
        let trimmed = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              viewModel.hasAuthenticatedUser
        else { return }
        commentText = ""
        shouldScrollToLatestComment = true
        Task {
            await viewModel.addComment(text: trimmed)
        }
    }

    private func confirmDeleteComment(_ comment: CommunityComment) {
        commentPendingDeletion = comment
        showDeleteCommentConfirm = true
    }

    private func deleteConfirmedComment() {
        guard let comment = commentPendingDeletion else { return }
        commentPendingDeletion = nil
        Task {
            await viewModel.deleteComment(comment)
        }
    }

    private func onOtherReasonTextChange(_ new: String) {
        if new.count > 200 {
            otherReasonText = String(new.prefix(200))
        }
    }

    private func toggleLike() {
        Task {
            await viewModel.toggleLike()
        }
    }

    private func confirmBlockUser() {
        showBlockConfirm = true
    }

    private func reportSpam() {
        confirmReport(.spam)
    }

    private func reportInappropriate() {
        confirmReport(.inappropriate)
    }

    private func openOtherReasonInput() {
        otherReasonText = ""
        showOtherReasonInput = true
    }

    private func submitOtherReport() {
        let trimmed = otherReasonText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        submitReport(.other(trimmed))
    }

    private func confirmReport(_ reason: ReportReason) {
        pendingReason = reason
        showReportConfirm = true
    }

    private func submitPendingReport() {
        guard let reason = pendingReason else { return }
        pendingReason = nil
        submitReport(reason)
    }

    private func blockUser() {
        viewModel.blockAuthor()
        dismiss()
    }

    private func submitReport(_ reason: ReportReason) {
        guard currentUserId != nil else { return }
        Task {
            await viewModel.submitReport(reason)
        }
    }
}

private struct StoryCardThumbnail: View {
    private let url: URL

    init(url: URL) {
        self.url = url
    }

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case let .success(image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                DSColor.fill
                    .overlay {
                        Image(.photo)
                            .foregroundStyle(.secondary)
                    }
            case .empty:
                DSColor.fill
                    .overlay {
                        ProgressView().controlSize(.small)
                    }
            @unknown default:
                DSColor.fill
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
