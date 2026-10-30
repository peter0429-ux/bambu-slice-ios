//
//  SlicerBridge.mm
//  ObjC++ 粘合层：把 ObjC 的 DTO 翻成 C++ 结构体，调用 bambu::SlicerCore。
//

#import "SlicerBridge.h"

#include <memory>
#include <string>
#include <vector>

#include "SlicerCore.hpp"

NSString * const BBSlicerErrorDomain = @"BBSlicerErrorDomain";

#pragma mark - 内部工具

static std::string toStd(NSString *s) {
    if (s == nil) return std::string();
    const char *utf8 = [s UTF8String];
    return utf8 ? std::string(utf8) : std::string();
}

static NSError *makeError(BBSlicerErrorCode code, NSString *message) {
    return [NSError errorWithDomain:BBSlicerErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: message ?: @"未知错误"}];
}

#pragma mark - BBMesh

@interface BBMesh ()
@property (nonatomic, readwrite, strong) NSData *vertexData;
@property (nonatomic, readwrite, strong) NSData *indexData;
@property (nonatomic, readwrite) NSUInteger vertexCount;
@property (nonatomic, readwrite) NSUInteger triangleCount;
@property (nonatomic, readwrite) BBAABB boundingBox;
@end

@implementation BBMesh
@end

#pragma mark - BBSliceSettings

@implementation BBSliceSettings

+ (instancetype)defaultSettings {
    BBSliceSettings *s = [[BBSliceSettings alloc] init];
    s.layerHeight        = 0.20;
    s.firstLayerHeight   = 0.25;
    s.nozzleDiameter     = 0.40;
    s.filamentDiameter   = 1.75;
    s.wallLoops          = 2;
    s.infillDensity      = 0.15;
    s.infillPattern      = @"grid";
    s.supportEnabled     = NO;
    s.supportThreshold   = 45.0;
    s.brimEnabled        = NO;
    s.nozzleTemp         = 220.0;
    s.bedTemp            = 60.0;
    s.printerProfile     = @"Bambu Lab A1 mini";
    s.bedWidth           = 180.0;
    s.bedDepth           = 180.0;
    s.bedHeight          = 180.0;
    s.overrides          = @{};
    return s;
}

- (instancetype)init {
    if ((self = [super init])) {
        _infillPattern = @"grid";
        _printerProfile = @"Bambu Lab A1 mini";
        _overrides = @{};
        _layerHeight = 0.2;
        _firstLayerHeight = 0.25;
        _nozzleDiameter = 0.4;
        _filamentDiameter = 1.75;
        _wallLoops = 2;
        _infillDensity = 0.15;
        _supportThreshold = 45.0;
        _nozzleTemp = 220.0;
        _bedTemp = 60.0;
        _bedWidth = 180.0;
        _bedDepth = 180.0;
        _bedHeight = 180.0;
    }
    return self;
}

@end

#pragma mark - BBSliceResult

@interface BBSliceResult ()
@property (nonatomic, readwrite, copy) NSString *gcode;
@property (nonatomic, readwrite) double estimatedDurationSeconds;
@property (nonatomic, readwrite) double filamentMillimeters;
@property (nonatomic, readwrite) double filamentGrams;
@property (nonatomic, readwrite) NSUInteger layerCount;
@property (nonatomic, readwrite, copy) NSString *backend;
@property (nonatomic, readwrite, copy) NSArray<NSString *> *warnings;
@end

@implementation BBSliceResult
@end

#pragma mark - BBSlicer

@implementation BBSlicer {
    std::unique_ptr<bambu::SlicerCore> _core;
}

- (instancetype)init {
    if ((self = [super init])) {
        _core = std::make_unique<bambu::SlicerCore>();
    }
    return self;
}

+ (BOOL)isCoreAvailable {
    return bambu::SlicerCore::core_available() ? YES : NO;
}

+ (NSString *)coreVersion {
    return [NSString stringWithUTF8String:bambu::SlicerCore::core_version().c_str()];
}

- (BBMesh *)loadModelAtPath:(NSString *)path error:(NSError **)error {
    if (path.length == 0) {
        if (error) *error = makeError(BBSlicerErrorModelLoadFailed, @"路径为空");
        return nil;
    }

    bambu::MeshData mesh;
    std::string err;
    if (!_core->load(toStd(path), mesh, err) || mesh.empty()) {
        if (error) *error = makeError(BBSlicerErrorModelLoadFailed,
                                      [NSString stringWithUTF8String:err.c_str()]);
        return nil;
    }

    BBMesh *result = [[BBMesh alloc] init];

    // std::vector → NSData，直接搬内存，避免逐个装箱 NSNumber（大模型会卡死主线程）
    result.vertexData = [NSData dataWithBytes:mesh.vertices.data()
                                       length:mesh.vertices.size() * sizeof(float)];
    result.indexData  = [NSData dataWithBytes:mesh.indices.data()
                                       length:mesh.indices.size() * sizeof(uint32_t)];
    result.vertexCount   = mesh.vertices.size() / 3;
    result.triangleCount = mesh.triangle_count;

    BBAABB bb;
    bb.minX = mesh.bounds.min[0]; bb.minY = mesh.bounds.min[1]; bb.minZ = mesh.bounds.min[2];
    bb.maxX = mesh.bounds.max[0]; bb.maxY = mesh.bounds.max[1]; bb.maxZ = mesh.bounds.max[2];
    result.boundingBox = bb;

    return result;
}

- (BBSliceResult *)sliceModelAtPath:(NSString *)path
                           settings:(BBSliceSettings *)settings
                           progress:(void (^)(double, NSString *))progress
                              error:(NSError **)error {
    if (path.length == 0) {
        if (error) *error = makeError(BBSlicerErrorSliceFailed, @"路径为空");
        return nil;
    }

    bambu::Settings s;
    s.layer_height        = settings.layerHeight;
    s.first_layer_height  = settings.firstLayerHeight;
    s.nozzle_diameter     = settings.nozzleDiameter;
    s.filament_diameter   = settings.filamentDiameter;
    s.wall_loops          = (int)settings.wallLoops;
    s.infill_density      = settings.infillDensity;
    s.infill_pattern      = toStd(settings.infillPattern);
    s.support_enabled     = settings.supportEnabled ? true : false;
    s.support_threshold   = settings.supportThreshold;
    for (NSNumber *n in settings.supportFacets) {
        if (n.intValue >= 0) s.support_facets.push_back(n.intValue);
    }
    s.brim_enabled        = settings.brimEnabled ? true : false;
    s.nozzle_temp         = settings.nozzleTemp;
    s.bed_temp            = settings.bedTemp;
    s.printer_profile     = toStd(settings.printerProfile);
    s.bed_width           = settings.bedWidth;
    s.bed_depth           = settings.bedDepth;
    s.bed_height          = settings.bedHeight;

    for (NSString *key in settings.overrides) {
        s.overrides.emplace_back(toStd(key), toStd(settings.overrides[key]));
    }

    // 进度块在同步调用期间一直活在调用者的栈帧里，直接按引用捕获即可。
    void (^progressBlock)(double, NSString *) = progress;
    bambu::ProgressFn fn;
    if (progressBlock != nil) {
        fn = [progressBlock](float fraction, const std::string &stage) {
            @autoreleasepool {
                progressBlock((double)fraction, [NSString stringWithUTF8String:stage.c_str()]);
            }
        };
    }

    bambu::SliceOutput out;
    std::string err;
    // 这层保护只拦 ObjC 异常（比如进度块里抛的）。C++ 异常已经在
    // libslic3r_backend::slice 内部 catch 过；真正的段错误（SIGSEGV）
    // 谁也拦不住，只能靠崩溃日志定位。
    BOOL ok = NO;
    @try {
        ok = _core->slice(toStd(path), s, fn, out, err) ? YES : NO;
    } @catch (NSException *ex) {
        if (error) {
            *error = makeError(BBSlicerErrorSliceFailed,
                               ex.reason ?: @"切片过程中发生异常");
        }
        return nil;
    }
    if (!ok) {
        if (error) {
            const BBSlicerErrorCode code =
                (err == "已取消") ? BBSlicerErrorCancelled : BBSlicerErrorSliceFailed;
            *error = makeError(code, [NSString stringWithUTF8String:err.c_str()]);
        }
        return nil;
    }

    BBSliceResult *result = [[BBSliceResult alloc] init];
    result.gcode = [NSString stringWithUTF8String:out.gcode.c_str()];
    result.estimatedDurationSeconds = out.duration_seconds;
    result.filamentMillimeters = out.filament_mm;
    result.filamentGrams = out.filament_grams;
    result.layerCount = out.layer_count;
    result.backend = [NSString stringWithUTF8String:out.backend.c_str()];

    NSMutableArray<NSString *> *warnings = [NSMutableArray array];
    for (const auto &w : out.warnings)
        [warnings addObject:[NSString stringWithUTF8String:w.c_str()]];
    result.warnings = warnings;

    return result;
}

- (void)cancel {
    if (_core) _core->request_cancel();
}

@end
