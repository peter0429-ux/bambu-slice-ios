import Foundation

enum SlicerError: LocalizedError {
    case load(String)
    case slice(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .load(let m):    return m
        case .slice(let m):   return m
        case .cancelled:      return "切片已取消"
        }
    }
}

struct SliceOutput {
    let gcode: String
    let durationSeconds: Double
    let filamentGrams: Double
    let filamentMillimeters: Double
    let layerCount: Int
    let backend: String
    let warnings: [String]
}

/// 内核入口。桥接调用是同步阻塞的，这里统一甩到后台队列。
final class BambuCoreEngine {

    private let slicer = BBSlicer()

    static var isCoreAvailable: Bool { BBSlicer.isCoreAvailable() }
    static var coreVersion: String { BBSlicer.coreVersion() }

    func loadModel(at url: URL) async throws -> Mesh {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Mesh, Error>) in
            DispatchQueue.global(qos: .userInitiated).async { [slicer] in
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }

                var error: NSError?
                guard let bridged = slicer.loadModel(atPath: url.path, error: &error) else {
                    cont.resume(throwing: SlicerError.load(error?.localizedDescription ?? "模型读取失败"))
                    return
                }
                cont.resume(returning: Mesh(bridge: bridged))
            }
        }
    }

    func slice(at url: URL,
               settings: SliceSettings,
               progress: @escaping (Double, String) -> Void) async throws -> SliceOutput {
        let bridgeSettings = settings.toBridge()

        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<SliceOutput, Error>) in
            DispatchQueue.global(qos: .userInitiated).async { [slicer] in
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }

                var error: NSError?
                guard let result = slicer.sliceModel(atPath: url.path,
                                                     settings: bridgeSettings,
                                                     progress: { fraction, stage in
                                                         progress(fraction, stage)
                                                     },
                                                     error: &error) else {
                    if let e = error, e.code == BBSlicerErrorCode.cancelled.rawValue {
                        cont.resume(throwing: SlicerError.cancelled)
                    } else {
                        cont.resume(throwing: SlicerError.slice(error?.localizedDescription ?? "切片失败"))
                    }
                    return
                }

                cont.resume(returning: SliceOutput(gcode: result.gcode,
                                                   durationSeconds: result.estimatedDurationSeconds,
                                                   filamentGrams: result.filamentGrams,
                                                   filamentMillimeters: result.filamentMillimeters,
                                                   layerCount: Int(result.layerCount),
                                                   backend: result.backend,
                                                   warnings: result.warnings))
            }
        }
    }

    func cancel() {
        slicer.cancel()
    }
}
