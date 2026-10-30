//
//  SlicerBridge.h
//  ObjC 门面。Swift 只通过这个头文件接触内核，看不到任何 C++ 类型。
//  由 BambuSlice-Bridging-Header.h 引入。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const BBSlicerErrorDomain;

typedef NS_ENUM(NSInteger, BBSlicerErrorCode) {
    BBSlicerErrorModelLoadFailed = 1,
    BBSlicerErrorSliceFailed     = 2,
    BBSlicerErrorCancelled       = 3,
    BBSlicerErrorUnsupported     = 4,
};

typedef struct BBAABB {
    double minX, minY, minZ;
    double maxX, maxY, maxZ;
} BBAABB;

/// 三角汤。vertexData 是 float32 的 x,y,z 连续数组，indexData 是 uint32 索引。
@interface BBMesh : NSObject
@property (nonatomic, readonly, strong) NSData *vertexData;
@property (nonatomic, readonly, strong) NSData *indexData;
@property (nonatomic, readonly) NSUInteger vertexCount;
@property (nonatomic, readonly) NSUInteger triangleCount;
@property (nonatomic, readonly) BBAABB boundingBox;
@end

@interface BBSliceSettings : NSObject
@property (nonatomic) double layerHeight;
@property (nonatomic) double firstLayerHeight;
@property (nonatomic) double nozzleDiameter;
@property (nonatomic) double filamentDiameter;
@property (nonatomic) NSInteger wallLoops;
/// 0.0 ~ 1.0
@property (nonatomic) double infillDensity;
@property (nonatomic, copy) NSString *infillPattern;
@property (nonatomic) BOOL supportEnabled;
@property (nonatomic) double supportThreshold;
/// 手绘强制支撑：STL 三角形索引。空数组表示不干预。
@property (nonatomic, copy) NSArray<NSNumber *> *supportFacets;
@property (nonatomic) BOOL brimEnabled;
@property (nonatomic) double nozzleTemp;
@property (nonatomic) double bedTemp;
@property (nonatomic, copy) NSString *printerProfile;
@property (nonatomic) double bedWidth;
@property (nonatomic) double bedDepth;
@property (nonatomic) double bedHeight;
/// 任意 libslic3r 配置项直通，key → 序列化值
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *overrides;

+ (instancetype)defaultSettings;
@end

@interface BBSliceResult : NSObject
@property (nonatomic, readonly, copy) NSString *gcode;
@property (nonatomic, readonly) double estimatedDurationSeconds;
@property (nonatomic, readonly) double filamentMillimeters;
@property (nonatomic, readonly) double filamentGrams;
@property (nonatomic, readonly) NSUInteger layerCount;
@property (nonatomic, readonly, copy) NSString *backend;
@property (nonatomic, readonly, copy) NSArray<NSString *> *warnings;
@end

@interface BBSlicer : NSObject

/// NO 表示当前二进制没链接 libslic3r，跑的是内置参考引擎。
+ (BOOL)isCoreAvailable;
+ (NSString *)coreVersion;

- (nullable BBMesh *)loadModelAtPath:(NSString *)path
                               error:(NSError * _Nullable * _Nullable)error;

/// 同步阻塞调用。Swift 侧请放到后台队列，别在主线程喊它。
- (nullable BBSliceResult *)sliceModelAtPath:(NSString *)path
                                    settings:(BBSliceSettings *)settings
                                    progress:(nullable void (^)(double fraction, NSString *stage))progress
                                       error:(NSError * _Nullable * _Nullable)error;

/// 尽力而为。真内核下能否立刻中断取决于 fork 里有没有 cancel 钩子。
- (void)cancel;

@end

NS_ASSUME_NONNULL_END
