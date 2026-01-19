import SwiftUI
import UniformTypeIdentifiers

/// Simple document picker for PDF/images.
struct DocumentPicker: UIViewControllerRepresentable {
    var allowedTypes: [UTType] = [.pdf, .image]
    let onPick: (PickedDocument) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedTypes, asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick, onCancel: onCancel) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (PickedDocument) -> Void
        let onCancel: () -> Void

        init(onPick: @escaping (PickedDocument) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCancel()
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { onCancel(); return }
            do {
                let data = try Data(contentsOf: url)
                let fileName = url.lastPathComponent
                let contentType = (UTType(filenameExtension: url.pathExtension)?.preferredMIMEType) ?? "application/octet-stream"
                onPick(PickedDocument(data: data, fileName: fileName, contentType: contentType))
            } catch {
                onCancel()
            }
        }
    }
}

struct PickedDocument {
    let data: Data
    let fileName: String
    let contentType: String
}
