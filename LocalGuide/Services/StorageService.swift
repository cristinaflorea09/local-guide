import Foundation
import FirebaseStorage
import UIKit

final class StorageService {
    static let shared = StorageService()
    private init() {}

    private let storage = Storage.storage()

    /// Uploads guide profile photo (JPEG) to `guides/{guideId}/profile.jpg` and returns URL.
    
    /// Uploads guide attestation (PDF/JPG/PNG) to `guides/{guideId}/attestation/{fileName}` and returns URL.
    func uploadGuideAttestation(uid: String, data: Data, fileName: String, contentType: String) async throws -> String {
        let safeName = fileName.replacingOccurrences(of: " ", with: "_")
        let ref = storage.reference(withPath: "guides/\(uid)/attestation/\(safeName)")
        let metadata = StorageMetadata()
        metadata.contentType = contentType

        _ = try await ref.putDataAsync(data, metadata: metadata)
        let url = try await ref.downloadURL()
        return url.absoluteString
    }

    func uploadGuidePhoto(uid: String, image: UIImage) async throws -> String {
        let url = try await uploadJPEG(image, path: "guides/\(uid)/profile.jpg", quality: 0.85)
        return url.absoluteString
    }

    func uploadUserPhoto(uid: String, image: UIImage) async throws -> String {
        let url = try await uploadJPEG(image, path: "users/\(uid)/profile.jpg", quality: 0.85)
        return url.absoluteString
    }

    /// Uploads business registration certificate (PDF/JPG/PNG) to `sellers/{uid}/business/{fileName}` and returns URL.
    func uploadBusinessCertificate(uid: String, data: Data, fileName: String, contentType: String) async throws -> String {
        let safeName = fileName.replacingOccurrences(of: " ", with: "_")
        let ref = storage.reference(withPath: "sellers/\(uid)/business/\(safeName)")
        let metadata = StorageMetadata()
        metadata.contentType = contentType
        _ = try await ref.putDataAsync(data, metadata: metadata)
        let url = try await ref.downloadURL()
        return url.absoluteString
    }

    /// Uploads a JPEG image and returns the download URL.
    func uploadJPEG(
        _ image: UIImage,
        path: String,
        quality: CGFloat = 0.85
    ) async throws -> URL {
        guard let data = image.jpegData(compressionQuality: quality) else {
            throw NSError(domain: "StorageService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to encode image"])
        }

        let ref = storage.reference(withPath: path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        _ = try await ref.putDataAsync(data, metadata: metadata)
        return try await ref.downloadURL()
    }
}

private extension StorageReference {
    func putDataAsync(_ data: Data, metadata: StorageMetadata?) async throws -> StorageMetadata {
        try await withCheckedThrowingContinuation { cont in
            self.putData(data, metadata: metadata) { meta, error in
                if let error = error { cont.resume(throwing: error); return }
                cont.resume(returning: meta ?? StorageMetadata())
            }
        }
    }

    func downloadURL() async throws -> URL {
        try await withCheckedThrowingContinuation { cont in
            self.downloadURL { url, error in
                if let error = error { cont.resume(throwing: error); return }
                if let url = url { cont.resume(returning: url); return }
                cont.resume(throwing: NSError(domain: "StorageService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Missing download URL"]))
            }
        }
    }
}
