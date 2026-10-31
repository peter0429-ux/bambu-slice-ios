import SwiftUI

struct SettingsSheet: View {
    @Binding var settings: SliceSettings
    @Environment(\.dismiss) private var dismiss
    /// 「暂停点」里待添加的层号
    @State private var newPauseLayer = 5

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(SlicePreset.all) { preset in
                            Button {
                                settings.apply(preset)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Text(preset.name)
                                            .font(.subheadline.weight(.semibold))
                                        if settings.matchedPreset == preset {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.caption2)
                                        }
                                    }
                                    Text(preset.detail)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(9)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(settings.matchedPreset == preset
                                              ? Color.accentColor.opacity(0.18)
                                              : Color.secondary.opacity(0.10))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                } header: {
                    Text("预设")
                } footer: {
                    Text("点一下套用整组参数，下面的滑杆会跟着变。改动任意一项就变成「自定义」。")
                }

                Section("打印机") {
                    Picker("机型", selection: $settings.printer) {
                        ForEach(PrinterPreset.all) { p in
                            Text(p.name).tag(p)
                        }
                    }
                    LabeledContent("热床", value: "\(Int(settings.bedWidth)) × \(Int(settings.bedDepth)) mm")
                }

                // ── 模型变换 ─────────────────────────────
                Section {
                    paramSlider("缩放",
                                value: $settings.modelScalePercent,
                                range: 10...400, step: 5,
                                format: "%.0f %%",
                                hint: "STL 单位搞错时用这里拉回来：英寸制的模型要 ×25.4，米制要 ×1000")
                    HStack(spacing: 8) {
                        ForEach([25.4, 50.0, 100.0, 200.0], id: \.self) { v in
                            Button(String(format: "%.4g%%", v)) {
                                settings.modelScalePercent = v
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        Spacer()
                    }
                    paramSlider("绕 Z 旋转",
                                value: $settings.modelRotateZ,
                                range: 0...360, step: 5,
                                format: "%.0f°",
                                hint: "只转水平方向；朝上倒扣需要在建模软件里改")
                } header: {
                    Text("模型")
                } footer: {
                    Text("预览会立刻跟着变，切片也用同一套变换。")
                }

                Section("质量") {
                    VStack(alignment: .leading) {
                        LabeledContent("层高", value: String(format: "%.2f mm", settings.layerHeight))
                        Slider(value: $settings.layerHeight, in: 0.08...0.32, step: 0.02)
                    }
                    VStack(alignment: .leading) {
                        LabeledContent("首层高度", value: String(format: "%.2f mm", settings.firstLayerHeight))
                        Slider(value: $settings.firstLayerHeight, in: 0.15...0.35, step: 0.05)
                    }
                    Stepper("墙层数：\(settings.wallLoops)",
                            value: $settings.wallLoops, in: 1...5)
                    VStack(alignment: .leading) {
                        LabeledContent("填充密度", value: "\(Int(settings.infillDensity * 100))%")
                        Slider(value: $settings.infillDensity, in: 0...0.6, step: 0.05)
                    }
                }

                // ── P1：壳层 / 顶底面 / 接缝 / 补偿 ──────────────
                Section {
                    Stepper("顶部壳层：\(settings.topShellLayers) 层",
                            value: $settings.topShellLayers, in: 0...12)
                    paramSlider("顶部壳厚",
                                value: $settings.topShellThickness,
                                range: 0...3, step: 0.1,
                                format: "%.1f mm",
                                hint: "层数与厚度取较大者生效")
                    Stepper("底部壳层：\(settings.bottomShellLayers) 层",
                            value: $settings.bottomShellLayers, in: 0...12)
                    paramSlider("底部壳厚",
                                value: $settings.bottomShellThickness,
                                range: 0...3, step: 0.1,
                                format: "%.1f mm")
                    Picker("垂直壳厚", selection: $settings.ensureVerticalShellThickness) {
                        Text("保证（全部斜面）").tag("enabled")
                        Text("仅关键区域").tag("partial")
                        Text("关闭").tag("disabled")
                    }
                    Toggle("首层单壁", isOn: $settings.onlyOneWallFirstLayer)
                } header: {
                    Text("壳层")
                }

                Section("顶底面图案") {
                    Picker("顶面", selection: $settings.topSurfacePattern) {
                        Text("单调线（推荐）").tag("monotonicline")
                        Text("单调").tag("monotonic")
                        Text("直线").tag("line")
                        Text("同心").tag("concentric")
                        Text("希尔伯特").tag("hilbertcurve")
                        Text("锯齿").tag("zig-zag")
                    }
                    Picker("底面", selection: $settings.bottomSurfacePattern) {
                        Text("单调线（推荐）").tag("monotonicline")
                        Text("单调").tag("monotonic")
                        Text("直线").tag("line")
                        Text("同心").tag("concentric")
                        Text("希尔伯特").tag("hilbertcurve")
                        Text("锯齿").tag("zig-zag")
                    }
                    Picker("内部实心", selection: $settings.internalSolidInfillPattern) {
                        Text("单调线（推荐）").tag("monotonicline")
                        Text("单调").tag("monotonic")
                        Text("直线").tag("line")
                        Text("同心").tag("concentric")
                        Text("锯齿").tag("zig-zag")
                    }
                }

                Section("接缝与顺序") {
                    Picker("接缝位置", selection: $settings.seamPosition) {
                        Text("对齐（推荐）").tag("aligned")
                        Text("最近").tag("nearest")
                        Text("背面").tag("back")
                        Text("随机").tag("random")
                    }
                    Picker("打壁顺序", selection: $settings.wallSequence) {
                        Text("内壁 → 外壁").tag("inner wall/outer wall")
                        Text("外壁 → 内壁").tag("outer wall/inner wall")
                        Text("内 → 外 → 内").tag("inner-outer-inner wall")
                    }
                    Picker("熨烫", selection: $settings.ironingType) {
                        Text("关闭").tag("no ironing")
                        Text("顶面").tag("top")
                        Text("仅最顶层").tag("topmost")
                        Text("全部实心面").tag("solid")
                    }
                }

                Section("尺寸补偿") {
                    paramSlider("象腿补偿",
                                value: $settings.elefantFootCompensation,
                                range: 0...1, step: 0.05,
                                format: "%.2f mm",
                                hint: "首层内缩，抵消热床边缘外扩")
                    paramSlider("XY 孔补偿",
                                value: $settings.xyHoleCompensation,
                                range: -0.5...0.5, step: 0.05,
                                format: "%.2f mm",
                                hint: "正值缩小孔洞（补偿材料收缩）")
                    paramSlider("XY 轮廓补偿",
                                value: $settings.xyContourCompensation,
                                range: -0.5...0.5, step: 0.05,
                                format: "%.2f mm",
                                hint: "正值放大外形")
                }

                // ── P2：速度 ──────────────────────────────────
                Section {
                    speedSlider("外壁", $settings.outerWallSpeed, 10...300, hint: "决定外观质量，越慢越好")
                    speedSlider("内壁", $settings.innerWallSpeed, 10...300)
                    speedSlider("稀疏填充", $settings.sparseInfillSpeed, 20...500, hint: "最快的一档，影响总时长")
                    speedSlider("内部实心", $settings.internalSolidInfillSpeed, 20...300)
                    speedSlider("顶面", $settings.topSurfaceSpeed, 10...300)
                    speedSlider("首层", $settings.initialLayerSpeed, 5...100, hint: "首层慢一点附着更牢")
                    speedSlider("首层填充", $settings.initialLayerInfillSpeed, 5...150)
                    speedSlider("空驶", $settings.travelSpeed, 30...600, hint: "不挤料时的移动速度")
                    speedSlider("桥接", $settings.bridgeSpeed, 5...100, hint: "悬空跨桥，太快会断")
                } header: {
                    Text("速度")
                }

                if settings.supportEnabled {
                    Section("支撑速度") {
                        speedSlider("支撑", $settings.supportSpeed, 10...300)
                        speedSlider("支撑接触面", $settings.supportInterfaceSpeed, 10...300)
                    }
                }

                // ── P3：回抽与 Z hop ─────────────────────────
                Section {
                    paramSlider("回抽长度",
                                value: $settings.retractionLength,
                                range: 0...5, step: 0.1,
                                format: "%.1f mm",
                                hint: "太短会拉丝，太长容易堵")
                    paramSlider("回抽速度",
                                value: $settings.retractionSpeed,
                                range: 5...100, step: 1,
                                format: "%.0f mm/s")
                    paramSlider("最小回抽距离",
                                value: $settings.retractionMinimumTravel,
                                range: 0...10, step: 0.5,
                                format: "%.1f mm",
                                hint: "空驶超过这个距离才回抽")
                    paramSlider("Z 抬升",
                                value: $settings.zHop,
                                range: 0...2, step: 0.1,
                                format: "%.1f mm",
                                hint: "回抽时抬头，避免撞到已打印部分")
                    Picker("Z 抬升方式", selection: $settings.zHopType) {
                        Text("螺旋").tag("Spiral Lift")
                        Text("自动").tag("Auto Lift")
                        Text("普通").tag("Normal Lift")
                        Text("斜向").tag("Slope Lift")
                    }
                } header: {
                    Text("回抽")
                }

                Section("擦拭与避让") {
                    Toggle("回抽时擦拭", isOn: $settings.wipeEnabled)
                    if settings.wipeEnabled {
                        paramSlider("擦拭距离",
                                    value: $settings.wipeDistance,
                                    range: 0...10, step: 0.5,
                                    format: "%.1f mm",
                                    hint: "喷嘴在壁面上蹭掉余料，减少拉丝")
                    }
                    Toggle("避免跨越外墙", isOn: $settings.reduceCrossingWall)
                }

                // ── P4：冷却风扇 ─────────────────────────────
                Section {
                    Stepper("最大风扇：\(settings.fanMaxSpeed)%", value: $settings.fanMaxSpeed, in: 0...100)
                    Stepper("最小风扇：\(settings.fanMinSpeed)%", value: $settings.fanMinSpeed, in: 0...100)
                    Stepper("前 \(settings.closeFanFirstXLayers) 层关风扇",
                            value: $settings.closeFanFirstXLayers, in: 0...20)
                    Stepper("从第 \(settings.fullFanSpeedLayer) 层起全速",
                            value: $settings.fullFanSpeedLayer, in: 0...50)
                } header: {
                    Text("风扇")
                }

                Section {
                    Toggle("按层耗时自动降速", isOn: $settings.slowDownForLayerCooling)
                    paramSlider("层耗时阈值",
                                value: Binding(
                                    get: { Double(settings.fanCoolingLayerTime) },
                                    set: { settings.fanCoolingLayerTime = Int($0) }
                                ),
                                range: 5...120, step: 1,
                                format: "%.0f s",
                                hint: "单层打完快于它，自动放慢让层冷却")
                    paramSlider("最短层时间",
                                value: Binding(
                                    get: { Double(settings.slowDownLayerTime) },
                                    set: { settings.slowDownLayerTime = Int($0) }
                                ),
                                range: 0...60, step: 1,
                                format: "%.0f s")
                    Stepper("悬垂风扇：\(settings.overhangFanSpeed)%",
                            value: $settings.overhangFanSpeed, in: 0...100)
                    Toggle("悬垂/桥接强制冷却", isOn: $settings.enableOverhangBridgeFan)
                } header: {
                    Text("冷却策略")
                }

                // ── 暂停点（换色 / 埋螺母）──────────────
                Section {
                    Stepper("待添加：第 \(newPauseLayer) 层",
                            value: $newPauseLayer, in: 1...2000)
                    Button("添加到暂停列表") {
                        settings.pauseLayers.insert(newPauseLayer)
                    }
                    .disabled(settings.pauseLayers.contains(newPauseLayer))

                    if !settings.pauseLayers.isEmpty {
                        ForEach(settings.pauseLayers.sorted(), id: \.self) { layer in
                            HStack {
                                Image(systemName: "pause.circle")
                                    .foregroundStyle(.secondary)
                                Text("第 \(layer) 层")
                                Spacer()
                                Button {
                                    settings.pauseLayers.remove(layer)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Button("清空", role: .destructive) {
                            settings.pauseLayers.removeAll()
                        }
                    }
                } header: {
                    Text("暂停点")
                } footer: {
                    Text("打印到该层时机器会暂停等你确认。指令插在抬 Z 之后，"
                         + "避免喷嘴停在上一层高度刮到已打好的部分。")
                }

                Section("材料") {
                    Stepper("喷嘴温度：\(Int(settings.nozzleTemp))℃",
                            value: $settings.nozzleTemp, in: 180...300, step: 5)
                    Stepper("热床温度：\(Int(settings.bedTemp))℃",
                            value: $settings.bedTemp, in: 0...110, step: 5)
                    LabeledContent("喷嘴直径", value: String(format: "%.1f mm", settings.nozzleDiameter))
                }

                Section("附着") {
                    Toggle("生成支撑", isOn: $settings.supportEnabled)
                    Toggle("Brim", isOn: $settings.brimEnabled)
                }

                // ── 支撑参数（对应 Bambu Studio 桌面版支撑面板）──
                // 关键项是「悬垂角阈值」：桌面版默认 30°，之前这里错用了 45°，
                // 结果只给大于 45° 的悬垂加支撑，看起来就是"支撑不够"。
                if settings.supportEnabled {
                    Section {
                        Picker("支撑类型", selection: $settings.supportType) {
                            Text("普通（自动）").tag("normal(auto)")
                            Text("树状（自动）").tag("tree(auto)")
                            Text("普通（手动）").tag("normal")
                            Text("树状（手动）").tag("tree")
                        }

                        paramSlider("悬垂角阈值",
                                    value: $settings.supportThreshold,
                                    range: 10...70, step: 1,
                                    format: "%.0f°",
                                    hint: "坡度低于该值的悬垂才生成支撑。调小 → 支撑更多")

                        Stepper("接触面层数：\(settings.supportInterfaceTopLayers)",
                                value: $settings.supportInterfaceTopLayers, in: 0...6)

                        Toggle("只在热床上生成", isOn: $settings.supportBuildplateOnly)
                        Toggle("过滤小块悬垂", isOn: $settings.supportRemoveSmallOverhang)
                    } header: {
                        Text("支撑")
                    }

                    Section {
                        paramSlider("顶面间隙",
                                    value: $settings.supportTopZDistance,
                                    range: 0...0.6, step: 0.02,
                                    format: "%.2f mm",
                                    hint: "支撑顶面离模型的缝，太小会粘牢撕坏表面")
                        paramSlider("底面间隙",
                                    value: $settings.supportBottomZDistance,
                                    range: 0...0.6, step: 0.02,
                                    format: "%.2f mm")
                        paramSlider("与模型水平距离",
                                    value: $settings.supportObjectXYDistance,
                                    range: 0...2, step: 0.05,
                                    format: "%.2f mm")
                        paramSlider("水平外扩",
                                    value: $settings.supportExpansion,
                                    range: 0...2, step: 0.1,
                                    format: "%.2f mm",
                                    hint: "调大让支撑更宽，更容易托住边缘悬垂")
                        paramSlider("底部图案间距",
                                    value: $settings.supportBasePatternSpacing,
                                    range: 0.5...10, step: 0.5,
                                    format: "%.1f mm",
                                    hint: "调小 → 支撑更密实，也更费料")
                        paramSlider("接触面线距",
                                    value: $settings.supportInterfaceSpacing,
                                    range: 0...2, step: 0.1,
                                    format: "%.2f mm")
                    } header: {
                        Text("支撑细节")
                    }

                    if settings.supportType.hasPrefix("tree") {
                        Section("树状支撑") {
                            paramSlider("分枝角",
                                        value: $settings.treeSupportBranchAngle,
                                        range: 10...80, step: 1,
                                        format: "%.0f°")
                            paramSlider("主干直径",
                                        value: $settings.treeSupportBranchDiameter,
                                        range: 0.5...10, step: 0.5,
                                        format: "%.1f mm")
                            Stepper("壁数：\(settings.treeSupportWallCount)",
                                    value: $settings.treeSupportWallCount, in: 0...4)
                        }
                    }
                }

                Section {
                    LabeledContent("内核", value: BambuCoreEngine.coreVersion)
                    if !BambuCoreEngine.isCoreAvailable {
                        Text("当前构建未链接 libslic3r，切片由内置参考引擎完成：无支撑/桥接，G-code 仅供预览。按 docs/PORTING.md 编好依赖后把 BAMBU_CORE_ENABLED 置 1 即可切换到真内核。")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                } header: {
                    Text("关于")
                }
            }
            .navigationTitle("切片参数")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    /// 统一风格的参数滑条：标题 + 当前值 + 滑杆 + 可选说明。
    @ViewBuilder
    private func paramSlider(_ title: String,
                             value: Binding<Double>,
                             range: ClosedRange<Double>,
                             step: Double,
                             format: String,
                             hint: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: format, value.wrappedValue))
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: step)
            if let hint {
                Text(hint)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// 速度滑条：统一 mm/s 单位，减少重复写法。
    @ViewBuilder
    private func speedSlider(_ title: String,
                             _ value: Binding<Double>,
                             _ range: ClosedRange<Double>,
                             hint: String? = nil) -> some View {
        paramSlider(title, value: value, range: range, step: 5,
                    format: "%.0f mm/s", hint: hint)
    }
}
