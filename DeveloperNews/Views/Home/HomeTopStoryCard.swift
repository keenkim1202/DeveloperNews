import SwiftUI
import Translation

struct HomeTopStoryCard: View {
    private let translator: any Translating
    private let item: ContentItem
    private let destination: HomeTabDestination
    private let onHide: () -> Void

    @State private var translationTrigger = 0
    @State private var showingTranslation = false

    init(
        translator: any Translating,
        item: ContentItem,
        destination: HomeTabDestination,
        onHide: @escaping () -> Void,
    ) {
        self.translator = translator
        self.item = item
        self.destination = destination
        self.onHide = onHide
    }

    private var displayTitle: String {
        showingTranslation ? translator.title(for: item) : item.title
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(.topStory, systemImage: "sparkles")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tint)
                Spacer()
                Button(action: hideTopStory) {
                    HStack(spacing: 4) {
                        Text(.hideForADay)
                        Image(systemName: "xmark")
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background {
                        Color(.tertiarySystemFill)
                    }
                    .clipShape(Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(.hideTopStoryForADay)
            }

            NavigationLink(value: destination) {
                HStack(alignment: .top, spacing: 10) {
                    HomeTopStoryThumbnail(url: item.thumbnailURL)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 6) {
                            Text(item.sourceName)
                                .lineLimit(1)
                            Text("·")
                            Text(relativeDateFormatter.localizedString(for: item.publishedAt, relativeTo: .now))
                                .lineLimit(1)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(.plain)

            if translator.canTranslate {
                Button(action: toggleTranslation) {
                    HStack(spacing: 2) {
                        Image(systemName: "translate")
                        Text(showingTranslation ? .translationShowOriginal : .translationShowTranslated)
                    }
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(showingTranslation ? Color.accentColor : Color.primary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            Color.accentColor.opacity(0.08)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            if let config = translator.makeConfiguration(), translationTrigger > 0 {
                Color.clear
                    .id(translationTrigger)
                    .translationTask(config) { session in
                        await translator.translateSingle(item, using: session)
                        showingTranslation = true
                    }
            }
        }
    }

    private func hideTopStory() {
        withAnimation(.easeInOut(duration: 0.2)) {
            onHide()
        }
    }

    private func toggleTranslation() {
        if translator.isTranslated(item) {
            showingTranslation.toggle()
        }
        else {
            translationTrigger &+= 1
        }
    }
}


struct HomeTopStoryThumbnail: View {
    private let url: URL?

    init(url: URL?) {
        self.url = url
    }

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        placeholder
                    case .empty:
                        Color(.tertiarySystemFill)
                            .overlay { ProgressView().controlSize(.small) }
                    @unknown default:
                        placeholder
                    }
                }
            }
            else {
                placeholder
            }
        }
        .frame(width: 60, height: 60)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var placeholder: some View {
        Color(.tertiarySystemFill)
            .overlay {
                Image(systemName: "newspaper")
                    .foregroundStyle(.secondary)
            }
    }
}

