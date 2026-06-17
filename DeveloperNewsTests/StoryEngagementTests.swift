import Testing
import Foundation
@testable import DeveloperNews

@MainActor
@Suite struct StoryEngagementTests {
    @Test func documentIdIsStableForSameURL() {
        let url = "https://example.com/some-story"
        #expect(StoryEngagement.documentId(for: url) == StoryEngagement.documentId(for: url))
    }

    @Test func documentIdDiffersForDifferentURLs() {
        let a = StoryEngagement.documentId(for: "https://example.com/a")
        let b = StoryEngagement.documentId(for: "https://example.com/b")
        #expect(a != b)
    }

    @Test func documentIdIsHexFromEightHashBytes() {
        // shortHash takes the first 8 bytes of the SHA-256 digest and renders
        // each as two hex characters, so the id is 16 hex characters wide.
        let id = StoryEngagement.documentId(for: "https://example.com/x")
        #expect(id.count == 16)
        #expect(id.allSatisfy { $0.isHexDigit })
    }

    @Test func documentIdMatchesShortHash() {
        let url = "https://example.com/story"
        #expect(StoryEngagement.documentId(for: url) == HashUtil.shortHash(url))
    }

    @Test func idMatchesDocumentIdConvention() {
        let url = "https://example.com/story"
        let engagement = StoryEngagement(
            id: StoryEngagement.documentId(for: url),
            storyURL: url,
            likeCount: 0,
            likedBy: [],
            commentCount: 0,
            viewCount: 0)
        #expect(engagement.id == StoryEngagement.documentId(for: url))
    }
}
