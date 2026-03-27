import SwiftUI
@_exported import DialKitCore

public enum DialPosition: String, CaseIterable {
    case topRight
    case topLeft
    case bottomRight
    case bottomLeft
}

public enum DialMode: String, CaseIterable {
    case drawer
    case inline
}

public struct DialRoot: View {
    @ObservedObject private var store: DialStore
    private let position: DialPosition
    private let defaultOpen: Bool
    private let mode: DialMode
    private let storageID: String
    private let showsFAB: Bool
    private let isPresented: Binding<Bool>?

    public init(
        position: DialPosition = .bottomRight,
        defaultOpen: Bool = false,
        mode: DialMode = .drawer,
        storageID: String = "default"
    ) {
        self.position = position
        self.defaultOpen = defaultOpen
        self.mode = mode
        self.storageID = storageID
        self.showsFAB = mode == .drawer
        self.isPresented = nil
        self._store = ObservedObject(wrappedValue: DialStore.shared)
    }

    public init(
        position: DialPosition = .bottomRight,
        storageID: String = "default",
        showsFAB: Bool = false,
        isPresented: Binding<Bool>
    ) {
        self.position = position
        self.defaultOpen = isPresented.wrappedValue
        self.mode = .drawer
        self.storageID = storageID
        self.showsFAB = showsFAB
        self.isPresented = isPresented
        self._store = ObservedObject(wrappedValue: DialStore.shared)
    }

    public var body: some View {
        Group {
            if store.panels.isEmpty {
                EmptyView()
            } else if mode == .inline {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(store.panels) { panel in
                        DialPanelContainer(panel: panel, defaultOpen: true, inline: true)
                    }
                }
            } else {
                DialDrawerHost(
                    store: store,
                    position: position,
                    defaultOpen: defaultOpen,
                    storageID: storageID,
                    showsFAB: showsFAB,
                    isPresented: isPresented
                )
            }
        }
    }
}
