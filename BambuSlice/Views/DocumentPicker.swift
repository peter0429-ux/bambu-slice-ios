import SwiftUI
import UniformTypeIdentifiers

/// 系统文档选择器的直接封装。
///
/// 不用 SwiftUI 的 `.fileImporter`，原因有两个：
/// 1. 它把 `allowedContentTypes` 卡死时，iCloud 文件的动态 UTI 对不上，
///    文件在处理里会「可见但点不动」。
/// 2. 关键点是 **asCopy: true**：交给系统先复制一份到 App 沙盒再返回，
///    iCloud 的占位文件会被系统下载好再复制。这样拿到的 URL 是普通本地文件，
///    不用处理安全作用域、不用 NSFileCoordinator，稳定性高一个量级。
struct DocumentPicker: UIViewControllerRepresentable {

    var onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let onPick: (URL) -> Void

        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController,
                            didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPick(url)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {}
    }
}
