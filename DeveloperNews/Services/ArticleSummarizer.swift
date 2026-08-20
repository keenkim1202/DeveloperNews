import FoundationModels
import Foundation

@MainActor
final class ArticleSummarizer: ArticleSummarizing {
    /// Enough of the article to summarize without overrunning the context
    /// window. Leading paragraphs carry most of a news piece.
    private static let maxCharacters = 6000
    private static let minimumCharacters = 400

    private static let instructions = """
    You summarize technical news articles for a developer audience.
    Reply with three to five short bullet lines, one per line, no numbering \
    and no leading punctuation. State what the article says; do not add \
    opinions, and do not repeat the headline.
    """

    var availability: SummaryAvailability {
        switch SystemLanguageModel.default.availability {
        case .available:
            .available
        case .unavailable(.appleIntelligenceNotEnabled):
            .appleIntelligenceOff
        case .unavailable(.modelNotReady):
            .modelNotReady
        default:
            .deviceNotEligible
        }
    }

    func summarize(
        title: String,
        paragraphs: [String],
    ) async throws -> [String] {
        guard availability == .available else {
            throw ArticleSummaryError.unavailable
        }

        let body = Self.trimmedBody(from: paragraphs)
        guard body.count >= Self.minimumCharacters else {
            throw ArticleSummaryError.notEnoughText
        }

        let session = LanguageModelSession(instructions: Self.instructions)
        let prompt = """
        Title: \(title)

        Article:
        \(body)
        """

        do {
            let response = try await session.respond(to: prompt)
            let lines = Self.bulletLines(from: response.content)
            guard !lines.isEmpty else {
                throw ArticleSummaryError.failed
            }
            return lines
        }
        catch is ArticleSummaryError {
            throw ArticleSummaryError.failed
        }
        catch {
            throw ArticleSummaryError.failed
        }
    }

    private static func trimmedBody(from paragraphs: [String]) -> String {
        var collected: [String] = []
        var length = 0
        for paragraph in paragraphs {
            let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                continue
            }
            if length + trimmed.count > maxCharacters {
                break
            }
            collected.append(trimmed)
            length += trimmed.count
        }
        return collected.joined(separator: "\n\n")
    }

    /// Models drift between plain lines and bulleted ones, so the markers are
    /// stripped rather than assumed absent.
    static func bulletLines(from text: String) -> [String] {
        text
            .split(separator: "\n")
            .map { line in
                line
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "-*• \t"))
                    .trimmingCharacters(in: .whitespaces)
            }
            .filter { !$0.isEmpty }
    }
}
