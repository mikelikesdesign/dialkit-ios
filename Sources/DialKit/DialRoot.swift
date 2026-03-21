import SwiftUI
@_exported import DialKitCore

public enum DialPosition: String, CaseIterable {
    case topRight
    case topLeft
    case bottomRight
    case bottomLeft

    fileprivate var alignment: Alignment {
        switch self {
        case .topRight:
            return .topTrailing
        case .topLeft:
            return .topLeading
        case .bottomRight:
            return .bottomTrailing
        case .bottomLeft:
            return .bottomLeading
        }
    }

    fileprivate var insets: EdgeInsets {
        switch self {
        case .topRight:
            return EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        case .topLeft:
            return EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        case .bottomRight:
            return EdgeInsets(top: 16, leading: 16, bottom: 32, trailing: 16)
        case .bottomLeft:
            return EdgeInsets(top: 16, leading: 16, bottom: 32, trailing: 16)
        }
    }
}

public enum DialMode: String, CaseIterable {
    case popover
    case inline
}

public struct DialRoot: View {
    @ObservedObject private var store: DialStore
    private let position: DialPosition
    private let defaultOpen: Bool
    private let mode: DialMode

    public init(
        position: DialPosition = .topRight,
        defaultOpen: Bool = true,
        mode: DialMode = .popover
    ) {
        self.position = position
        self.defaultOpen = defaultOpen
        self.mode = mode
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
                GeometryReader { _ in
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .overlay(alignment: position.alignment) {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(store.panels) { panel in
                                    DialPanelContainer(panel: panel, defaultOpen: defaultOpen, inline: false)
                                }
                            }
                            .padding(position.insets)
                        }
                        .ignoresSafeArea()
                }
            }
        }
    }
}
