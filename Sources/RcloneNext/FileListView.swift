import SwiftUI
import AppKit

struct FileListView: View {
    @Environment(AppModel.self) private var app
    @State var model: BrowserModel
    @State private var sortOrder = [KeyPathComparator(\RcloneItem.name)]
    @State private var search = ""
    @State private var notice: Notice?

    struct Notice: Identifiable { let id = UUID(); let title: String; let message: String }

    private var displayedItems: [RcloneItem] {
        let filtered = search.isEmpty
            ? model.items
            : model.items.filter { $0.name.localizedCaseInsensitiveContains(search) }
        return filtered.sorted(using: sortOrder)
    }

    var body: some View {
        Table(displayedItems, selection: $model.selection, sortOrder: $sortOrder) {
            TableColumn("Name") { item in
                Label(item.name, systemImage: item.isDir ? "folder.fill" : SFIcon.forMime(item.mimeType))
                    .foregroundStyle(item.isDir ? Color.accentColor : .primary)
            }
            TableColumn("Size") { item in
                Text(item.isDir ? "—" : ByteCountFormatter.string(
                    fromByteCount: item.size, countStyle: .file))
                    .foregroundStyle(.secondary).monospacedDigit()
            }.width(90)
            TableColumn("Modified") { item in
                Text(item.modTime?.formatted(date: .abbreviated, time: .shortened) ?? "—")
                    .foregroundStyle(.secondary)
            }.width(170)
        }
        .contextMenu(forSelectionType: RcloneItem.ID.self) { ids in
            contextMenu(for: model.items.filter { ids.contains($0.id) })
        } primaryAction: { ids in
            guard let item = model.items.first(where: { ids.contains($0.id) }) else { return }
            Task { if item.isDir { await model.open(item) } else { await model.openFile(item) } }
        }
        .overlay { if model.isLoading { ProgressView().controlSize(.large) } }
        .safeAreaInset(edge: .top, spacing: 0) { breadcrumbBar }
        .safeAreaInset(edge: .bottom) { transferBar }
        .searchable(text: $search, placement: .toolbar, prompt: "Filter")
        .navigationTitle(model.remote.name)
        .toolbar { toolbarContent }
        .task(id: model.pathStack) { await model.load() }
        .alert("Error", isPresented: .constant(model.error != nil)) {
            Button("OK") { model.error = nil }
        } message: { Text(model.error ?? "") }
        .alert(notice?.title ?? "", isPresented: Binding(
            get: { notice != nil }, set: { if !$0 { notice = nil } }), presenting: notice) { _ in
            Button("OK") {}
        } message: { Text($0.message) }
    }

    // MARK: Breadcrumb

    private var breadcrumbBar: some View {
        HStack(spacing: 4) {
            crumb(model.remote.name,
                  icon: SFIcon.forRemoteType(app.type(of: model.remote)),
                  isCurrent: model.pathStack.isEmpty) { Task { await model.go(to: 0) } }
            ForEach(Array(model.pathStack.enumerated()), id: \.offset) { idx, comp in
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                crumb(comp, icon: nil, isCurrent: idx == model.pathStack.count - 1) {
                    Task { await model.go(to: idx + 1) }
                }
            }
            Spacer()
        }
        .font(.callout)
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) { Divider() }
    }

    @ViewBuilder
    private func crumb(_ text: String, icon: String?, isCurrent: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            if let icon {
                Label(text, systemImage: icon).symbolRenderingMode(.hierarchical)
            } else {
                Text(text)
            }
        }
        .buttonStyle(.plain)
        .fontWeight(isCurrent ? .semibold : .regular)
        .foregroundStyle(isCurrent ? .primary : Color.accentColor)
        .disabled(isCurrent)
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button { Task { await model.goUp() } } label: { Image(systemName: "chevron.up") }
                .disabled(model.pathStack.isEmpty).help("Up one level")
                .keyboardShortcut(.upArrow, modifiers: .command)
        }
        ToolbarItemGroup {
            Button { mountAction() } label: { Image(systemName: "externaldrive.badge.plus") }
                .help("Mount this remote…")
            Button { newFolderAction() } label: { Image(systemName: "folder.badge.plus") }
                .help("New Folder")
            Button { uploadAction() } label: { Image(systemName: "arrow.up.circle") }
                .help("Upload…")
            Button { downloadSelection() } label: { Image(systemName: "arrow.down.circle") }
                .disabled(model.selection.isEmpty).help("Download…")
            Button(role: .destructive) { deleteSelection() } label: {
                Image(systemName: "trash")
            }.disabled(model.selection.isEmpty).help("Delete")
            Button { Task { await model.load(forceRefresh: true) } } label: {
                Image(systemName: "arrow.clockwise")
            }.help("Refresh")
        }
    }

    @ViewBuilder
    private func contextMenu(for items: [RcloneItem]) -> some View {
        if items.count == 1 {
            let item = items[0]
            Button("Open") {
                Task { if item.isDir { await model.open(item) } else { await model.openFile(item) } }
            }
            if item.isDir {
                Button("Calculate Size") {
                    Task { if let s = await model.calculateSize(item) {
                        notice = Notice(title: "Folder Size", message: s) } }
                }
            }
            Button("Rename…") { renameItem(item) }
            Button("Copy Link") { Task { await copyLink(item) } }
            Divider()
        }
        Button("Download…") { Task { await download(items) } }
        Divider()
        Button("Delete", role: .destructive) { confirmDelete(items) }
    }

    // MARK: Live transfer indicator (native material)

    @ViewBuilder
    private var transferBar: some View {
        if let t = model.activeTransfer {
            HStack(spacing: 12) {
                ProgressView(value: t.fraction).frame(width: 160)
                Text("\(ByteCountFormatter.string(fromByteCount: t.bytes, countStyle: .file)) "
                   + "of \(ByteCountFormatter.string(fromByteCount: t.totalBytes, countStyle: .file))")
                    .font(.callout).monospacedDigit()
                Spacer()
                Text("\(ByteCountFormatter.string(fromByteCount: Int64(t.speed), countStyle: .file))/s")
                    .font(.callout).foregroundStyle(.secondary).monospacedDigit()
                Button("Cancel") { app.cancelActiveTransfer() }
                    .buttonStyle(.borderless)
            }
            .padding(.horizontal).padding(.vertical, 8)
            .background(.ultraThinMaterial)
        }
    }

    // MARK: Actions

    private func mountAction() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Mount Here"
        panel.message = "Choose an empty folder to mount “\(model.remote.name)”."
        if panel.runModal() == .OK, let folder = panel.url { model.mount(at: folder) }
    }

    private func newFolderAction() {
        if let name = AlertHelpers.promptText("New Folder", message: "Folder name:", default: "untitled folder") {
            Task { await model.makeFolder(named: name) }
        }
    }

    private func renameItem(_ item: RcloneItem) {
        if let name = AlertHelpers.promptText("Rename", message: "New name:", default: item.name) {
            Task { await model.rename(item, to: name) }
        }
    }

    private func copyLink(_ item: RcloneItem) async {
        guard let url = await model.publicLink(item) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url, forType: .string)
        notice = Notice(title: "Link Copied", message: url)
    }

    private func uploadAction() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true; panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            Task { await model.upload(localURL: url) }
        }
    }

    private func downloadSelection() {
        Task { await download(model.items.filter { model.selection.contains($0.id) }) }
    }

    private func download(_ items: [RcloneItem]) async {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false; panel.canChooseDirectories = true
        panel.prompt = "Download Here"
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        for item in items { await model.download(item, to: folder) }
    }

    private func deleteSelection() {
        let items = model.items.filter { model.selection.contains($0.id) }
        confirmDelete(items)
    }

    private func confirmDelete(_ items: [RcloneItem]) {
        guard !items.isEmpty else { return }
        let noun = items.count == 1 ? "item" : "items"
        if AlertHelpers.confirm(
            "Delete \(items.count) \(noun)?",
            message: "This permanently removes them from the remote.",
            confirmTitle: "Delete",
            style: .critical
        ) {
            Task { await model.delete(items) }
        }
    }
}

/// SF Symbols for file MIME types and rclone backend types.
enum SFIcon {
    static func forMime(_ mime: String?) -> String {
        switch mime ?? "" {
        case let m where m.hasPrefix("image"): return "photo"
        case let m where m.hasPrefix("video"): return "film"
        case let m where m.hasPrefix("audio"): return "music.note"
        case let m where m.hasPrefix("text"):  return "doc.text"
        case "application/pdf":                 return "doc.richtext"
        default:                                return "doc"
        }
    }

    static func forRemoteType(_ type: String?) -> String {
        switch type ?? "" {
        case "drive":                                   return "externaldrive.connected.to.line.below"
        case "onedrive", "box", "pcloud", "mega",
             "jottacloud", "yandex", "hidrive":         return "cloud.fill"
        case "dropbox":                                 return "shippingbox.fill"
        case "s3", "b2", "gcs", "googlecloudstorage",
             "swift", "azureblob":                      return "server.rack"
        case "sftp", "ftp", "webdav", "http":           return "network"
        case "local", "alias", "crypt":                 return "folder.fill"
        case "googlephotos":                            return "photo.stack.fill"
        default:                                        return "externaldrive"
        }
    }
}
