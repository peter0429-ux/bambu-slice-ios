import SwiftUI

/// App 内的模型库：直接列出沙盒里的 STL/OBJ，不依赖系统选择器。
/// 同时也提供「从文件选择」入口（走 asCopy 的系统选择器，iCloud 文件会被系统下载好再交过来）。
struct ModelLibraryView: View {

    @ObservedObject var vm: SlicerViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showPicker = false

    var body: some View {
        NavigationStack {
            List {
                if vm.localModels.isEmpty {
                    emptySection
                } else {
                    filesSection
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("模型库")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showPicker = true
                    } label: {
                        Label("从文件选择", systemImage: "folder.badge.plus")
                    }
                }
            }
            .task { vm.refreshLocalModels() }
            .overlay {
                if vm.isBusy {
                    ZStack {
                        Color.black.opacity(0.35).ignoresSafeArea()
                        VStack(spacing: 10) {
                            ProgressView().tint(.orange)
                            Text(vm.stage.isEmpty ? "读取中…" : vm.stage)
                                .font(.caption)
                        }
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
            .sheet(isPresented: $showPicker) {
                DocumentPicker { url in
                    showPicker = false
                    Task {
                        await vm.importModel(from: url)
                        if vm.hasModel { dismiss() }
                    }
                }
                .ignoresSafeArea()
            }
        }
    }

    // MARK: - 列表

    private var filesSection: some View {
        Section {
            ForEach(vm.localModels) { file in
                Button {
                    Task {
                        await vm.importModel(from: file.url)
                        if vm.hasModel { dismiss() }
                    }
                } label: {
                    row(file)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        vm.deleteModel(file)
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
            }
        } header: {
            Text("App 文件夹 · \(vm.localModels.count) 个模型")
        } footer: {
            Text("把 STL 用「文件」App 复制到 BambuSlice 文件夹，这里就会列出来。左滑可以删除。")
        }
    }

    private func row(_ file: ModelFile) -> some View {
        HStack(spacing: 12) {
            Image(systemName: file.url.pathExtension.lowercased() == "obj" ? "cube.transparent" : "cube")
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("\(file.sizeText) · \(file.dateText)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 6)

            if vm.fileName == file.name && vm.hasModel {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .contentShape(Rectangle())
    }

    private var emptySection: some View {
        Section {
            VStack(spacing: 10) {
                Image(systemName: "tray")
                    .font(.system(size: 34, weight: .thin))
                    .foregroundStyle(.secondary)
                Text("文件夹里还没有模型")
                    .font(.subheadline.weight(.medium))
                Text("点右上角「从文件选择」挑一个，或者\n用「文件」App 把 STL 复制进 BambuSlice 文件夹")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
        }
    }
}
