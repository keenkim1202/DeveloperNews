import SwiftUI

// Shared comment row. The post comment UI is the canonical design, so the feed
// post, community post, and story comment screens all render this. It owns the
// per-comment moderation menu (delete for own comments; report/block for
// others') plus its own confirm/reason alert state so callers only forward the
// resulting action.
struct CommentRow: View {
    private let comment: CommunityComment
    private let currentUserId: String?
    private let onDelete: (() -> Void)?
    private let onReport: ((ReportReason) -> Void)?
    private let onBlock: (() -> Void)?
    private let onLike: (() -> Void)?

    @State private var showDeleteConfirm = false
    @State private var showReportConfirm = false
    @State private var showBlockConfirm = false
    @State private var showOtherReasonInput = false
    @State private var otherReasonText = ""
    @State private var pendingReason: ReportReason?

    init(
        comment: CommunityComment,
        currentUserId: String?,
        onDelete: (() -> Void)?,
        onReport: ((ReportReason) -> Void)?,
        onBlock: (() -> Void)?,
        onLike: (() -> Void)?,
    ) {
        self.comment = comment
        self.currentUserId = currentUserId
        self.onDelete = onDelete
        self.onReport = onReport
        self.onBlock = onBlock
        self.onLike = onLike
    }

    private var isOwnComment: Bool {
        comment.authorId == currentUserId
    }
    private var canDelete: Bool {
        isOwnComment && onDelete != nil
    }
    private var canModerate: Bool {
        !isOwnComment && currentUserId != nil && onReport != nil && onBlock != nil
    }
    private var isLiked: Bool {
        currentUserId.map { comment.likedBy.contains($0) } ?? false
    }

    var body: some View {
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
                if canDelete {
                    deleteMenu
                }
                else if canModerate {
                    moderationMenu
                }
            }
            Text(comment.text)
                .font(.subheadline)
            likeControl
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background {
            DSColor.surface
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .alert(
            .communityDeleteCommentConfirm,
            isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button(
                "Delete",
                role: .destructive,
                action: performDelete)
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
        .alert(.communityReportReasonOtherTitle, isPresented: $showOtherReasonInput) {
            TextField(.communityReportReasonOtherPlaceholder, text: $otherReasonText)
                .keenOnChange(of: otherReasonText, perform: onOtherReasonTextChange)
            Button("Cancel", role: .cancel) {}
            Button(.communityReport, action: submitOtherReport)
        } message: {
            Text(.communityReportReasonOtherMessage)
        }
        .alert(
            .communityBlockConfirmTitle,
            isPresented: $showBlockConfirm) {
            Button("Cancel", role: .cancel) {}
            Button(
                .communityBlockConfirmAction,
                role: .destructive,
                action: performBlock)
        } message: {
            Text(.communityBlockConfirmMessage)
        }
    }

    private var likeControl: some View {
        Button(action: performLike) {
            HStack(spacing: 4) {
                Image(isLiked ? .likeFilled : .like)
                    .foregroundStyle(isLiked ? .red : .secondary)
                Text("\(comment.likeCount)")
            }
            .font(.caption)
        }
        .buttonStyle(.plain)
        .disabled(onLike == nil)
    }

    private var deleteMenu: some View {
        Menu {
            Button(role: .destructive, action: confirmDelete) {
                Label("Delete", systemImage: "trash")
            }
        } label: {
            menuLabel
        }
        .buttonStyle(.plain)
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
                action: confirmBlock)
        } label: {
            menuLabel
        }
        .buttonStyle(.plain)
    }

    private var menuLabel: some View {
        Image(.more)
            .font(.caption2)
            .foregroundStyle(.secondary)
    }

    private func performLike() {
        onLike?()
    }

    private func confirmDelete() {
        showDeleteConfirm = true
    }

    private func performDelete() {
        onDelete?()
    }

    private func reportSpam() {
        confirmReport(.spam)
    }

    private func reportInappropriate() {
        confirmReport(.inappropriate)
    }

    private func confirmReport(_ reason: ReportReason) {
        pendingReason = reason
        showReportConfirm = true
    }

    private func submitPendingReport() {
        guard let reason = pendingReason else {
            return
        }
        pendingReason = nil
        onReport?(reason)
    }

    private func openOtherReasonInput() {
        otherReasonText = ""
        showOtherReasonInput = true
    }

    private func submitOtherReport() {
        let trimmed = otherReasonText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }
        onReport?(.other(trimmed))
    }

    private func onOtherReasonTextChange(_ new: String) {
        if new.count > 200 {
            otherReasonText = String(new.prefix(200))
        }
    }

    private func confirmBlock() {
        showBlockConfirm = true
    }

    private func performBlock() {
        onBlock?()
    }
}
