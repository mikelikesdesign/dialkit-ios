import DialKitCore
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct DialVersionItem: Identifiable {
    let id: UUID?
    let name: String
}

extension AnyDialPanelBox {
    var versionItems: [DialVersionItem] {
        [DialVersionItem(id: nil, name: baseVersionName)] +
            presets.map { DialVersionItem(id: $0.id, name: $0.name) }
    }

    func selectVersion(_ id: UUID?) {
        switch dialPresetSelectionAction(for: id) {
        case .clear: clearActivePreset()
        case let .load(id): loadPreset(id: id)
        }
    }
}

struct DialVersionPreview {
    let image: Image
    let size: CGSize

    init?(data: Data) {
        #if canImport(UIKit)
        guard let source = UIImage(data: data) else { return nil }
        image = Image(uiImage: source)
        #elseif canImport(AppKit)
        guard let source = NSImage(data: data) else { return nil }
        image = Image(nsImage: source)
        #endif
        size = source.size
    }

    var aspectRatio: CGFloat { min(1.5, max(0.90, size.width / max(size.height, 1))) }
}

struct DialVersionHistory: View {
    @ObservedObject var panel: AnyDialPanelBox
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var renameTarget: DialVersionItem?
    @State private var deleteTarget: DialVersionItem?
    @State private var draftName = ""

    var body: some View {
        let items = panel.versionItems
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Versions").font(.title.bold()).accessibilityAddTraits(.isHeader)
                    Text("\(panel.name) · \(items.count) \(items.count == 1 ? "version" : "versions")")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.subheadline.bold())
                        .frame(width: 32, height: 32).background(.quaternary, in: Circle())
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close versions")
            }
            .padding(.horizontal, 20).padding(.top, 24).padding(.bottom, 16)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                        ForEach(items) { item in card(item).id(item.id) }
                    }
                    .padding(.horizontal, 20).padding(.bottom, 20)
                }
                .onAppear {
                    if panel.activePresetID != nil { proxy.scrollTo(panel.activePresetID) }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .presentationDetents(typeSize.isAccessibilitySize ? [.large] : [.medium, .large])
        .presentationDragIndicator(.visible)
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 360)
        #endif
        .alert("Rename Version", isPresented: presented($renameTarget), presenting: renameTarget) { item in
            TextField("Version name", text: $draftName)
            Button("Save") { panel.renameVersion(id: item.id, name: draftName) }
                .disabled(draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button("Cancel", role: .cancel) {}
        }
        .alert("Delete Version?", isPresented: presented($deleteTarget), presenting: deleteTarget) { item in
            Button("Delete", role: .destructive) {
                if let id = item.id { panel.deletePreset(id: id) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { item in
            Text(item.id == panel.activePresetID ?
                 "Deleting “\(item.name)” returns this panel to “\(panel.baseVersionName)”." :
                 "“\(item.name)” will be removed from this panel.")
        }
    }

    private var columns: [GridItem] {
        typeSize.isAccessibilitySize ? [GridItem(.flexible())] :
            [GridItem(.adaptive(minimum: 145, maximum: 260), spacing: 12, alignment: .top)]
    }

    private func presented(_ target: Binding<DialVersionItem?>) -> Binding<Bool> {
        Binding(get: { target.wrappedValue != nil }, set: { if !$0 { target.wrappedValue = nil } })
    }

    private func select(_ item: DialVersionItem) {
        panel.selectVersion(item.id)
        dismiss()
    }

    private func card(_ item: DialVersionItem) -> some View {
        let selected = item.id == panel.activePresetID
        let preview = panel.thumbnail(for: item.id).flatMap(DialVersionPreview.init)
        return ZStack(alignment: .bottomTrailing) {
            Button { select(item) } label: {
                VStack(alignment: .leading, spacing: 0) {
                    ZStack {
                        Color.secondary.opacity(0.10)
                        if let preview {
                            preview.image.resizable().scaledToFit()
                        } else {
                            Image(systemName: "photo").font(.title3).foregroundStyle(.secondary)
                        }
                    }
                    .aspectRatio(preview?.aspectRatio ?? 1.5, contentMode: .fit)
                    .clipShape(.rect(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(selected ? Color.accentColor : .secondary.opacity(0.2),
                                          lineWidth: selected ? 2.5 : 1)
                    }
                    HStack(spacing: 5) {
                        if selected {
                            DialVersionCheckmark()
                        }
                        Text(item.name).font(.subheadline.weight(.semibold))
                            .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.trailing, 44)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: 44)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.name)
            .accessibilityHint(preview == nil ? "No preview available. Loads this version." :
                                "Loads this version and returns to the editor")
            .accessibilityAddTraits(selected ? [.isSelected] : [])
            .contextMenu { actions(item) }

            Menu { actions(item) } label: {
                Image(systemName: "ellipsis").frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .foregroundStyle(.secondary)
            .accessibilityLabel("Actions for \(item.name)")
        }
    }

    @ViewBuilder private func actions(_ item: DialVersionItem) -> some View {
        Button {
            draftName = item.name
            renameTarget = item
        } label: { Label("Rename", systemImage: "pencil") }
        if item.id != nil {
            Button(role: .destructive) { deleteTarget = item } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

}
