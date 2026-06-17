import SwiftUI

struct FeedPostComposerView: View {
    private static let commentLimit = 280

    @State private var viewModel: FeedPostComposerViewModel
    private let item: ContentItem

    @State private var comment = ""
    @State private var isPosting = false

    @Environment(\.dismiss) private var dismiss

    init(
        appState: AppState,
        item: ContentItem,
    ) {
        _viewModel = State(initialValue: FeedPostComposerViewModel(
            appState: appState,
            item: item))
        self.item = item
    }

    private var canPost: Bool {
        !comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isPosting
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    quoteCard
                    LimitedTextEditor(
                        text: $comment,
                        limit: Self.commentLimit,
                        placeholder: .feedPostCommentPlaceholder)
                }
                .padding(20)
                .contentShape(Rectangle())
                .onTapGesture(perform: dismissKeyboard)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(.feedPostComposeTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: cancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: post) {
                        Text(.feedPostPost)
                    }
                    .disabled(!canPost)
                }
            }
        }
    }

    private var quoteCard: some View {
        HStack(alignment: .top, spacing: 12) {
            if let thumbnailURL = item.thumbnailURL {
                FeedPostThumbnailView(url: thumbnailURL)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.dsCardTitle)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                Text(item.sourceName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background {
            DSColor.surface
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func cancel() {
        dismiss()
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil)
    }

    private func post() {
        guard !isPosting else {
            return
        }
        isPosting = true
        Task {
            let didPost = await viewModel.post(comment: comment)
            isPosting = false
            if didPost {
                dismiss()
            }
        }
    }
}


private struct FeedPostThumbnailView: View {
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
