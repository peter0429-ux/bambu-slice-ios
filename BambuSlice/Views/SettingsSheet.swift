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
}
