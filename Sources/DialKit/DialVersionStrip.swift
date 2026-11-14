import Combine
import DialKitCore
import SwiftUI

struct DialVersionStrip: View {
    @ObservedObject var panel: AnyDialPanelBox
    let height: CGFloat
    let showsHistory: Bool
    let captureCurrent: () -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 8) {
                    ForEach(panel.versionItems) { item in
                        let selected = item.id == panel.activePresetID
                        Button {
                            guard !selected else { return }
                            captureCurrent()
                            panel.selectVersion(item.id)
                        } label: {
                            VersionTile(name: item.name, selected: selected, data: panel.thumbnail(for: item.id))
                                .frame(width: height * 1.05)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Switch to \(item.name)")
                        .accessibilityAddTraits(selected ? [.isSelected] : [])
                        .id(item.id)
                    }
                }
                .padding(.vertical, 3)
            }
            .scrollIndicators(.hidden)
            .accessibilityIdentifier("Version strip")
            .onChange(of: panel.activePresetID, initial: true) { _, id in
                proxy.scrollTo(id)
            }
        }
        .padding(.bottom, 5)
        .frame(height: height)
        .task(id: showsHistory) {
            guard !showsHistory else { return }
            // Wait until edits settle before taking a new picture of the active design.
            let settled = panel.objectWillChange.prepend(())
                .debounce(for: .milliseconds(450), scheduler: RunLoop.main)
            for await _ in settled.values {
                guard !Task.isCancelled else { return }
                if panel.thumbnail(for: panel.activePresetID) == nil { captureCurrent() }
            }
        }
    }
}

private struct VersionTile: View {
    let name: String
    let selected: Bool
    let data: Data?
    @State private var preview: DialVersionPreview?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            RoundedRectangle(cornerRadius: 7)
                .fill(.white.opacity(0.06))
                .overlay {
                    if let preview, selected || data != nil {
                        preview.image.resizable().scaledToFit()
                    } else {
                        Image(systemName: "photo").foregroundStyle(.white.opacity(0.5))
                    }
                }
                .clipShape(.rect(cornerRadius: 7))
                .overlay {
                    RoundedRectangle(cornerRadius: 7)
                        .strokeBorder(.white.opacity(selected ? 0.95 : 0.12), lineWidth: selected ? 2 : 1)
                }
            HStack(spacing: 3) {
                if selected { DialVersionCheckmark() }
                Text(name).lineLimit(1)
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white.opacity(selected ? 0.95 : 0.65))
        }
        .contentShape(Rectangle())
        .onChange(of: data, initial: true) { _, newValue in
            // Keep the previous frame visible while the active preview is being refreshed.
            if let newValue { preview = DialVersionPreview(data: newValue) }
        }
    }
}
