import SwiftUI

struct SettingsSheet: View {
    @Binding var settings: SliceSettings
    @Environment(\.dismiss) private var dismiss

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
}
