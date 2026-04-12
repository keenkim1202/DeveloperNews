import FirebaseStorage
import Foundation
import UIKit

enum ImageUploadService {
    private static let storage = Storage.storage()
    private static let maxDimension: CGFloat = 1024
    private static let compressionQuality: CGFloat = 0.7

    static func upload(_ image: UIImage, path: String) async throws -> String {
        guard let data = compress(image) else {
            throw ImageUploadError.compressionFailed
        }

        let ref = storage.reference().child(path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        _ = try await ref.putDataAsync(data, metadata: metadata)
        let url = try await ref.downloadURL()
        return url.absoluteString
    }

    static func delete(path: String) async {
        do {
            try await storage.reference().child(path).delete()
        }
        catch {
            // Deletion failed silently
        }
    }

    private static func compress(_ image: UIImage) -> Data? {
        let size = image.size
        let scale: CGFloat
        if max(size.width, size.height) > maxDimension {
            scale = maxDimension / max(size.width, size.height)
        }
        else {
            scale = 1
        }

        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }

        return resized.jpegData(compressionQuality: compressionQuality)
    }
}

enum ImageUploadError: LocalizedError {
    case compressionFailed

    var errorDescription: String? {
        "Failed to compress image."
    }
}
