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

                // 注意：ObjC 里最后一个 NSError** 参数会被 Swift 自动桥接成 throws，
                // 调用时不能再写 error: &error，而且返回值也会变成非 Optional
                // （失败通过 throw 表达），所以这里不能用 guard let。
                do {
                    let bridged = try slicer.loadModel(atPath: url.path)
                    cont.resume(returning: Mesh(bridge: bridged))
                } catch {
                    cont.resume(throwing: SlicerError.load(error.localizedDescription))
                }
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

                do {
                    let result = try slicer.sliceModel(atPath: url.path,
                                                       settings: bridgeSettings,
                                                       progress: { fraction, stage in
                                                           progress(fraction, stage)
                                                       })

                    cont.resume(returning: SliceOutput(gcode: result.gcode,
                                                       durationSeconds: result.estimatedDurationSeconds,
                                                       filamentGrams: result.filamentGrams,
                                                       filamentMillimeters: result.filamentMillimeters,
                                                       layerCount: Int(result.layerCount),
                                                       backend: result.backend,
                                                       warnings: result.warnings))
                } catch {
                    let ns = error as NSError
                    if ns.domain == BBSlicerErrorDomain,
                       ns.code == BBSlicerErrorCode.cancelled.rawValue {
                        cont.resume(throwing: SlicerError.cancelled)
                    } else {
                        cont.resume(throwing: SlicerError.slice(error.localizedDescription))
                    }
                }
            }
        }
    }

    func cancel() {
        slicer.cancel()
    }
}
