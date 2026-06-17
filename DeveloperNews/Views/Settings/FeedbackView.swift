import SwiftUI
import CoreImage.CIFilterBuiltins

struct FeedbackView: View {
    private static let instagramURLString = "https://www.instagram.com/developernews.zizic?igsh=dnRzMTBnNms0ZjRw&utm_source=qr"

    @Environment(\.dismiss) private var dismiss

    private var instagramURL: URL {
        URL(static: "https://www.instagram.com/developernews.zizic?igsh=dnRzMTBnNms0ZjRw&utm_source=qr")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let qr = QRCodeGenerator.generate(from: Self.instagramURLString) {
                        Image(uiImage: qr)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 260)
                            .padding(.top, 24)
                    }

                    Text((try? AttributedString(
                        markdown: String(localized: .feedbackInstagramMessage),
                        options: AttributedString.MarkdownParsingOptions(
                            interpretedSyntax: .inlineOnlyPreservingWhitespace)))
                        ?? AttributedString(String(localized: .feedbackInstagramMessage)))
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    Link(destination: instagramURL) {
                        HStack {
                            Image(.camera)
                            Text("@developernews.zizic")
                                .font(.body.weight(.semibold))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background {
                            DSColor.accent
                        }
                        .foregroundStyle(DSColor.onAccent)
                        .clipShape(Capsule())
                    }

                    Spacer(minLength: 40)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 40)
            }
            .navigationTitle(.sendFeedback)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: cancel)
                }
            }
        }
    }

    private func cancel() {
        dismiss()
    }
}


enum QRCodeGenerator {
    static func generate(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter(name: "CIQRCodeGenerator")
        filter?.setValue(Data(string.utf8), forKey: "inputMessage")
        filter?.setValue("H", forKey: "inputCorrectionLevel")

        guard let output = filter?.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))

        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

