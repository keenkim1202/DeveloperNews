import SwiftUI

/// The saved text of an article, shown when the page itself will not load.
///
/// Deliberately plain: this is a fallback for a reader with no network, not a
/// second rendering of the site.
struct OfflineArticleView: View {
    private let article: OfflineArticle

    init(article: OfflineArticle) {
        self.article = article
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                banner
                Text(article.title)
                    .font(.title2.weight(.semibold))
                Text(article.sourceName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Divider()
                ForEach(Array(article.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                    Text(paragraph)
                        .font(.body)
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
    }

    private var banner: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(.offlineReadingOffline, icon: .document)
                .font(.dsLabel)
                .foregroundStyle(DSColor.accent)
            Text(.offlineDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(relativeDateFormatter.localizedString(for: article.capturedAt, relativeTo: .now))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background {
            DSColor.surface
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
