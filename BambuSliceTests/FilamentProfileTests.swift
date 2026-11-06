import XCTest
@testable import BambuSlice

/// 耗材预设表 / 板型表的静态一致性检查。
///
/// 这几张表是"手抄"上游 JSON 来的，抄错一个数字不会崩溃、不会报错，
/// 只会让打印件温度不对 —— 最容易被忽略也最贵的一类错误。
/// 所以把关键约束写成断言，改表时 CI 会拦。
final class FilamentProfileTests: XCTestCase {

    // MARK: - 耗材表

    func testAllFilamentKindsHaveDistinctIds() {
        let ids = FilamentKind.all.map { $0.id }
        XCTAssertEqual(Set(ids).count, ids.count,
                       "耗材 id 有重复，Picker 会选不中：\(ids)")
    }

    func testFilamentTemperaturesAreInPhysicalRange() {
        for kind in FilamentKind.all {
            // 低于 180 挤不出 PLA，高于 310 会分解聚四氟乙烯/碳化
            XCTAssertTrue((180...310).contains(kind.nozzleTemp),
                          "\(kind.id) 喷嘴温度 \(kind.nozzleTemp)℃ 超出合理范围")
            // 热床 0~120：0 是"不开热床"（TPU/部分 PLA 场景），110 是 PC 上限
            XCTAssertTrue((0...120).contains(kind.bedTemp),
                          "\(kind.id) 热床温度 \(kind.bedTemp)℃ 超出合理范围")
        }
    }

    func testFilamentDensitiesMatchMaterialScience() {
        // 这三组密度是区分耗材类别的硬指标，抄错会直接影响耗材重量估算。
        let expected: [String: Double] = [
            "PLA": 1.24, "PETG": 1.27, "ABS": 1.04,
            "ASA": 1.04, "TPU": 1.24, "PC": 1.04, "PA": 1.04,
        ]
        for (id, density) in expected {
            guard let kind = FilamentKind.find(id) else {
                XCTFail("耗材表里没有 \(id)"); continue
            }
            XCTAssertEqual(kind.density, density, accuracy: 0.001,
                           "\(id) 密度应为 \(density) g/cm³")
        }
    }

    func testVolumetricSpeedIsPositive() {
        // 0 在引擎里表示"不限制"，但 UI 上 0 已经被赋予"自动"的语义，
        // 预设表里给 0 会让用户看不到真实的默认值。
        for kind in FilamentKind.all {
            XCTAssertGreaterThan(kind.maxVolumetricSpeed, 0,
                                 "\(kind.id) 体积极限流速必须为正数")
        }
    }

    /// PLA 的限速必须足够跑得动默认速度，
    /// 否则"默认配置"本身就是慢的，用户会以为 App 有问题。
    ///
    /// 默认外壁 60mm/s、层高 0.2、线宽 0.42 → 每毫米 0.084mm³ →
    /// 需要 60 × 0.084 ≈ 5.0mm³/s。PLA 给的 12 有 2.4 倍余量。
    func testDefaultFilamentLeavesHeadroomForDefaultSpeed() {
        guard let pla = FilamentKind.find("PLA") else {
            return XCTFail("找不到 PLA")
        }
        let nozzle: Double = 0.4
        let layer: Double = 0.2
        let lineWidth = nozzle * 1.05
        let mm3PerMM = layer * lineWidth
        let needed = 60.0 * mm3PerMM     // 默认外壁速度 60mm/s
        XCTAssertGreaterThan(pla.maxVolumetricSpeed, needed * 1.5,
                             "PLA 限速 \(pla.maxVolumetricSpeed) 对默认 60mm/s 只有 1.5 倍余量"
                             + "（需要 \(needed)mm³/s），用户一调快就会被压住")
    }

    func testFindIsCaseInsensitive() {
        XCTAssertNotNil(FilamentKind.find("pla"))
        XCTAssertNotNil(FilamentKind.find("Petg"))
        XCTAssertNil(FilamentKind.find("UNOBTAINIUM"))
    }

    // MARK: - 板型表

    /// 板型 id 必须精确匹配上游 `s_keys_map_BedType` 的字符串。
    /// 差一个字母 / 少一个空格，`set_str(curr_bed_type)` 就会失败，
    /// 热床温度写进错误的键 → 完全不生效，而且不报错。
    func testBedPlateIdsMatchUpstreamEnumStrings() {
        let upstream = [
            "Cool Plate",
            "Engineering Plate",
            "High Temp Plate",
            "Textured PEI Plate",
            "Supertack Plate",
        ]
        let ours = Set(BedPlate.all.map { $0.id })
        XCTAssertEqual(ours, Set(upstream),
                       "板型 id 与上游 enum 字符串不一致。"
                       + "少了：\(Set(upstream).subtracting(ours))，"
                       + "多了：\(ours.subtracting(Set(upstream)))")
    }

    func testDefaultBedTypeExistsInTable() {
        // SliceSettings 的默认值必须能在表里找到，
        // 否则 Picker 一开始就没有选中项（显示空白）。
        let s = SliceSettings()
        XCTAssertTrue(BedPlate.all.contains { $0.id == s.bedType },
                      "默认板型 \(s.bedType) 不在 BedPlate.all 里")
        XCTAssertTrue(FilamentKind.all.contains { $0.id == s.filamentType },
                      "默认耗材 \(s.filamentType) 不在 FilamentKind.all 里")
    }

    // MARK: - 桥接传递

    /// 新增的 4 个字段必须真的过桥。
    ///
    /// 之前踩过的坑：`s.overrides = ov` 写在参数填充之前，
    /// Swift 字典是值类型，提前赋值等于复制一份 → 所有参数静默丢失。
    /// 桥接层同理：漏一行赋值不会报错，只会让设置无效。
    func testNewMaterialFieldsCrossTheBridge() {
        var s = SliceSettings()
        s.nozzleTemp = 231
        s.nozzleTempFirstLayer = 207
        s.bedTemp = 77
        s.bedType = "High Temp Plate"
        s.filamentType = "PETG"
        s.maxVolumetricSpeed = 18.5

        let b = s.toBridge()
        XCTAssertEqual(b.nozzleTemp, 231, accuracy: 0.001)
        XCTAssertEqual(b.nozzleTempFirstLayer, 207, accuracy: 0.001)
        XCTAssertEqual(b.bedTemp, 77, accuracy: 0.001)
        XCTAssertEqual(b.bedType, "High Temp Plate")
        XCTAssertEqual(b.filamentType, "PETG")
        XCTAssertEqual(b.maxVolumetricSpeed, 18.5, accuracy: 0.001)
    }

    /// 桥接层的默认值必须和 Swift 侧一致。
    /// 之前 supportThreshold 桥接里是 45、Swift 里是 30，
    /// 只要某条路径没显式赋值就会用错阈值。
    func testBridgeDefaultsMatchSwiftDefaults() {
        let swiftDefaults = SliceSettings()
        let bridgeDefaults = BBSliceSettings.default()

        XCTAssertEqual(bridgeDefaults.supportThreshold,
                       swiftDefaults.supportThreshold, accuracy: 0.001)
        XCTAssertEqual(bridgeDefaults.nozzleTemp,
                       swiftDefaults.nozzleTemp, accuracy: 0.001)
        XCTAssertEqual(bridgeDefaults.bedTemp,
                       swiftDefaults.bedTemp, accuracy: 0.001)
        XCTAssertEqual(bridgeDefaults.bedType, swiftDefaults.bedType)
        XCTAssertEqual(bridgeDefaults.filamentType, swiftDefaults.filamentType)
        XCTAssertEqual(bridgeDefaults.maxVolumetricSpeed,
                       swiftDefaults.maxVolumetricSpeed, accuracy: 0.001)
    }
}
