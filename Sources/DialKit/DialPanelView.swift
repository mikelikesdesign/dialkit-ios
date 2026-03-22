import SwiftUI
import DialKitCore
#if canImport(UIKit)
import UIKit
#endif

private enum DialTheme {
    static let panelBackground = dialColor(from: "#212121") ?? Color(.sRGB, white: 0.13, opacity: 1)
    static let border = Color.white.opacity(0.10)
    static let borderSoft = Color.white.opacity(0.06)
    static let surface = Color.white.opacity(0.05)
    static let surfaceActive = Color.white.opacity(0.11)
    static let textRoot = Color.white
    static let textSection = Color.white.opacity(0.70)
    static let textLabel = Color.white.opacity(0.70)
    static let textMuted = Color.white.opacity(0.40)
    static let shadow = Color.black.opacity(0.45)
}

private extension DialSpringEditorMode {
    var label: String {
        switch self {
        case .simple:
            return "Time"
        case .advanced:
            return "Physics"
        }
    }
}

private extension DialTransitionMode {
    var label: String {
        switch self {
        case .easing:
            return "Easing"
        case .simple:
            return "Time"
        case .advanced:
            return "Physics"
        }
    }
}

package enum DialDrawerPresentation: Equatable {
    case hidden
    case medium
    case tall

    var isExpanded: Bool {
        self != .hidden
    }
}

package enum DialFABStorage {
    private struct StoredPoint: Codable {
        let x: Double
        let y: Double
    }

    package static func key(for storageID: String) -> String {
        "DialKit.fab-position.\(storageID)"
    }

    package static func load(storageID: String, userDefaults: UserDefaults = .standard) -> CGPoint? {
        guard let data = userDefaults.data(forKey: key(for: storageID)),
              let point = try? JSONDecoder().decode(StoredPoint.self, from: data) else {
            return nil
        }

        return CGPoint(x: point.x, y: point.y)
    }

    package static func save(_ point: CGPoint?, storageID: String, userDefaults: UserDefaults = .standard) {
        let storageKey = key(for: storageID)
        guard let point else {
            userDefaults.removeObject(forKey: storageKey)
            return
        }

        let stored = StoredPoint(x: point.x, y: point.y)
        guard let data = try? JSONEncoder().encode(stored) else {
            return
        }

        userDefaults.set(data, forKey: storageKey)
    }
}

package func dialNextDrawerPresentation(from current: DialDrawerPresentation, translationHeight: CGFloat) -> DialDrawerPresentation {
    guard abs(translationHeight) > 40 else {
        return current
    }

    if translationHeight < 0 {
        switch current {
        case .hidden:
            return .medium
        case .medium:
            return .tall
        case .tall:
            return .tall
        }
    }

    switch current {
    case .tall:
        return .medium
    case .medium:
        return .hidden
    case .hidden:
        return .hidden
    }
}

package func dialResolvedPanelSelection(current: UUID?, available: [UUID]) -> UUID? {
    guard !available.isEmpty else {
        return nil
    }

    if let current, available.contains(current) {
        return current
    }

    return available.first
}

package let dialDrawerContentInset: CGFloat = 12
package let dialDrawerHorizontalInset: CGFloat = 8
package let dialDrawerToolbarBottomPadding: CGFloat = 6

private let dialDrawerHandleSectionHeight: CGFloat = 27
private let dialDrawerPanelPickerSectionHeight: CGFloat = 40
private let dialDrawerToolbarSectionHeight: CGFloat = 42

package func dialDrawerShowsPanelPicker(panelCount: Int) -> Bool {
    panelCount > 1
}

package func dialResolvedDrawerWidth(containerWidth: CGFloat) -> CGFloat {
    max(containerWidth - (dialDrawerHorizontalInset * 2), 0)
}

package func dialDrawerChromeHeight(panelCount: Int) -> CGFloat {
    dialDrawerHandleSectionHeight
        + dialDrawerToolbarSectionHeight
        + (dialDrawerShowsPanelPicker(panelCount: panelCount) ? dialDrawerPanelPickerSectionHeight : 0)
}

package func dialDrawerHeightCap(
    presentation: DialDrawerPresentation,
    mediumMaxHeight: CGFloat,
    tallMaxHeight: CGFloat
) -> CGFloat {
    switch presentation {
    case .hidden:
        return 0
    case .medium:
        return mediumMaxHeight
    case .tall:
        return tallMaxHeight
    }
}

package func dialResolvedDrawerHeight(
    presentation: DialDrawerPresentation,
    intrinsicContentHeight: CGFloat,
    mediumMaxHeight: CGFloat,
    tallMaxHeight: CGFloat
) -> CGFloat {
    guard presentation != .hidden else {
        return 0
    }

    return min(max(intrinsicContentHeight, 0), dialDrawerHeightCap(
        presentation: presentation,
        mediumMaxHeight: mediumMaxHeight,
        tallMaxHeight: tallMaxHeight
    ))
}

package func dialDrawerControlsHeightCap(
    presentation: DialDrawerPresentation,
    panelCount: Int,
    mediumMaxHeight: CGFloat,
    tallMaxHeight: CGFloat
) -> CGFloat {
    max(
        dialDrawerHeightCap(
            presentation: presentation,
            mediumMaxHeight: mediumMaxHeight,
            tallMaxHeight: tallMaxHeight
        ) - dialDrawerChromeHeight(panelCount: panelCount),
        0
    )
}

package func dialSnappedSliderValue(_ raw: Double, range: ClosedRange<Double>, step: Double) -> Double {
    dialRound(raw, step: step, within: range)
}

package func dialShouldEmitSliderHaptic(previousValue: Double?, nextValue: Double) -> Bool {
    guard let previousValue else {
        return false
    }

    return previousValue != nextValue
}

#if canImport(UIKit)
package func dialClampedFABCenter(
    _ point: CGPoint,
    in size: CGSize,
    safeAreaInsets: UIEdgeInsets,
    diameter: CGFloat,
    horizontalMargin: CGFloat,
    topMargin: CGFloat,
    bottomMargin: CGFloat
) -> CGPoint {
    let radius = diameter / 2
    let minX = radius + horizontalMargin + safeAreaInsets.left
    let maxX = max(minX, size.width - radius - horizontalMargin - safeAreaInsets.right)
    let minY = radius + topMargin + safeAreaInsets.top
    let maxY = max(minY, size.height - radius - bottomMargin - safeAreaInsets.bottom)

    return CGPoint(
        x: min(max(point.x, minX), maxX),
        y: min(max(point.y, minY), maxY)
    )
}

package func dialDefaultFABCenter(
    for position: DialPosition,
    in size: CGSize,
    safeAreaInsets: UIEdgeInsets,
    diameter: CGFloat,
    horizontalMargin: CGFloat,
    topMargin: CGFloat,
    bottomMargin: CGFloat
) -> CGPoint {
    let radius = diameter / 2
    let minX = radius + horizontalMargin + safeAreaInsets.left
    let maxX = max(minX, size.width - radius - horizontalMargin - safeAreaInsets.right)
    let minY = radius + topMargin + safeAreaInsets.top
    let maxY = max(minY, size.height - radius - bottomMargin - safeAreaInsets.bottom)

    switch position {
    case .topRight:
        return CGPoint(x: maxX, y: minY)
    case .topLeft:
        return CGPoint(x: minX, y: minY)
    case .bottomRight:
        return CGPoint(x: maxX, y: maxY)
    case .bottomLeft:
        return CGPoint(x: minX, y: maxY)
    }
}
#endif

struct DialDrawerHost: View {
    @ObservedObject private var store: DialStore
    let position: DialPosition
    let defaultOpen: Bool
    let storageID: String

    @State private var drawerPresentation: DialDrawerPresentation
    @State private var drawerVisualPresentation: DialDrawerPresentation
    @State private var showsDrawerOverlay: Bool
    @State private var selectedPanelID: UUID?
    @State private var fabPosition: CGPoint?

    init(store: DialStore, position: DialPosition, defaultOpen: Bool, storageID: String) {
        self._store = ObservedObject(wrappedValue: store)
        self.position = position
        self.defaultOpen = defaultOpen
        self.storageID = storageID
        self._drawerPresentation = State(initialValue: defaultOpen ? .medium : .hidden)
        self._drawerVisualPresentation = State(initialValue: .medium)
        self._showsDrawerOverlay = State(initialValue: defaultOpen)
        self._selectedPanelID = State(initialValue: nil)
        self._fabPosition = State(initialValue: DialFABStorage.load(storageID: storageID))
    }

    private var activePanel: AnyDialPanelBox? {
        let resolvedID = dialResolvedPanelSelection(current: selectedPanelID, available: store.panels.map(\.id))
        return store.panels.first(where: { $0.id == resolvedID }) ?? store.panels.first
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if showsDrawerOverlay, let activePanel {
                    ZStack(alignment: .bottom) {
                        if drawerPresentation.isExpanded {
                            Color.black.opacity(0.001)
                                .ignoresSafeArea()
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    hideDrawer()
                                }
                        }

                        DialDrawerPanel(
                            panel: activePanel,
                            panels: store.panels,
                            selectedPanelID: $selectedPanelID,
                            presentation: activeDrawerPresentation,
                            containerSize: proxy.size,
                            onDrag: handleDrawerDrag
                        )
                        .padding(.horizontal, dialDrawerHorizontalInset)
                        .offset(y: drawerPresentation == .hidden ? proxy.size.height + 24 : 0)
                        .allowsHitTesting(drawerPresentation.isExpanded)
                    }
                }

                if !showsDrawerOverlay {
                    ZStack(alignment: .topLeading) {
                        Color.clear
                            .allowsHitTesting(false)

                        DraggableFABOverlay(
                            containerSize: proxy.size,
                            safeAreaInsets: proxy.safeAreaInsets.uiEdgeInsets,
                            initialPosition: position,
                            position: $fabPosition,
                            action: { presentDrawer(.medium) }
                        )
                    }
                    .ignoresSafeArea()
                    .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
        }
        .onAppear {
            selectedPanelID = dialResolvedPanelSelection(current: selectedPanelID, available: store.panels.map(\.id))
        }
        .onChange(of: store.panels.map(\.id)) { _, ids in
            selectedPanelID = dialResolvedPanelSelection(current: selectedPanelID, available: ids)
        }
        .onChange(of: fabPosition) { _, newValue in
            DialFABStorage.save(newValue, storageID: storageID)
        }
    }

    private var activeDrawerPresentation: DialDrawerPresentation {
        drawerPresentation == .hidden ? drawerVisualPresentation : drawerPresentation
    }

    private func handleDrawerDrag(_ translationHeight: CGFloat) {
        let target = dialNextDrawerPresentation(from: drawerPresentation, translationHeight: translationHeight)
        guard target != drawerPresentation else {
            return
        }

        if target == .hidden {
            hideDrawer()
        } else {
            presentDrawer(target)
        }
    }

    private func presentDrawer(_ target: DialDrawerPresentation) {
        if !showsDrawerOverlay {
            drawerVisualPresentation = target
            drawerPresentation = .hidden
            withAnimation(fabAppearanceAnimation) {
                showsDrawerOverlay = true
            }

            DispatchQueue.main.async {
                withAnimation(drawerAnimation) {
                    drawerVisualPresentation = target
                    drawerPresentation = target
                }
            }
            return
        }

        withAnimation(drawerAnimation) {
            drawerVisualPresentation = target
            drawerPresentation = target
        }
    }

    private func hideDrawer() {
        drawerVisualPresentation = activeDrawerPresentation

        withAnimation(drawerAnimation) {
            drawerPresentation = .hidden
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) {
            if drawerPresentation == .hidden {
                withAnimation(fabAppearanceAnimation) {
                    showsDrawerOverlay = false
                }
            }
        }
    }

    private var drawerAnimation: Animation {
        .spring(response: 0.32, dampingFraction: 0.86)
    }

    private var fabAppearanceAnimation: Animation {
        .spring(response: 0.22, dampingFraction: 0.9)
    }
}

private struct DialDrawerPanel: View {
    @ObservedObject var panel: AnyDialPanelBox
    let panels: [AnyDialPanelBox]
    @Binding var selectedPanelID: UUID?
    let presentation: DialDrawerPresentation
    let containerSize: CGSize
    let onDrag: (CGFloat) -> Void

    @State private var measuredControlsContentHeight: CGFloat = 0

    var body: some View {
        let width = dialResolvedDrawerWidth(containerWidth: containerSize.width)
        let mediumMaxHeight = min(containerSize.height * 0.58, 560)
        let tallMaxHeight = min(containerSize.height * 0.90, containerSize.height - 12)
        let controlsHeightCap = dialDrawerControlsHeightCap(
            presentation: presentation,
            panelCount: panels.count,
            mediumMaxHeight: mediumMaxHeight,
            tallMaxHeight: tallMaxHeight
        )
        let heightCap = dialDrawerHeightCap(
            presentation: presentation,
            mediumMaxHeight: mediumMaxHeight,
            tallMaxHeight: tallMaxHeight
        )
        let intrinsicHeight = dialDrawerChromeHeight(panelCount: panels.count) + measuredControlsContentHeight
        let resolvedHeight = dialResolvedDrawerHeight(
            presentation: presentation,
            intrinsicContentHeight: intrinsicHeight,
            mediumMaxHeight: mediumMaxHeight,
            tallMaxHeight: tallMaxHeight
        )

        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(Color.white.opacity(0.22))
                .frame(width: 42, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
                .padding(.bottom, 12)

            if dialDrawerShowsPanelPicker(panelCount: panels.count) {
                panelPicker
                    .padding(.horizontal, dialDrawerContentInset)
                    .padding(.bottom, 8)
            }

            DialPanelControlsView(
                panel: panel,
                toolbarBottomPadding: dialDrawerToolbarBottomPadding,
                contentBottomPadding: dialDrawerContentInset,
                maxControlsHeight: controlsHeightCap,
                onMeasuredControlsHeight: { newHeight in
                    guard abs(measuredControlsContentHeight - newHeight) > 0.5 else {
                        return
                    }

                    measuredControlsContentHeight = newHeight
                }
            )
        }
        .frame(width: width)
        .frame(height: measuredControlsContentHeight > 0 ? resolvedHeight : nil, alignment: .top)
        .frame(maxHeight: heightCap, alignment: .top)
        .background {
            DialPanelBackground(cornerRadius: 24)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(DialTheme.border, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: DialTheme.shadow, radius: 32, y: 8)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .gesture(
            DragGesture(minimumDistance: 16)
                .onEnded { gesture in
                    onDrag(gesture.translation.height)
                }
        )
    }

    private var panelPicker: some View {
        HStack(spacing: 0) {
            Menu {
                ForEach(panels) { candidate in
                    Button(candidate.name) {
                        selectedPanelID = candidate.id
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(panel.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DialTheme.textRoot)
                        .lineLimit(1)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DialTheme.textLabel.opacity(0.8))
                }
                .frame(height: 32)
                .padding(.horizontal, 10)
                .background(DialRowBackground(cornerRadius: 8))
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
    }
}

private struct DialPanelControlsView: View {
    @ObservedObject var panel: AnyDialPanelBox
    let toolbarBottomPadding: CGFloat
    let contentBottomPadding: CGFloat
    let maxControlsHeight: CGFloat?
    let onMeasuredControlsHeight: ((CGFloat) -> Void)?

    @State private var copiedState = false

    init(
        panel: AnyDialPanelBox,
        toolbarBottomPadding: CGFloat = 8,
        contentBottomPadding: CGFloat = 12,
        maxControlsHeight: CGFloat? = nil,
        onMeasuredControlsHeight: ((CGFloat) -> Void)? = nil
    ) {
        self.panel = panel
        self.toolbarBottomPadding = toolbarBottomPadding
        self.contentBottomPadding = contentBottomPadding
        self.maxControlsHeight = maxControlsHeight
        self.onMeasuredControlsHeight = onMeasuredControlsHeight
    }

    private var activePresetName: String {
        panel.presets.first(where: { $0.id == panel.activePresetID })?.name ?? "Version 1"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            toolbar
                .padding(.horizontal, dialDrawerContentInset)
                .padding(.bottom, toolbarBottomPadding)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 6) {
                    ForEach(panel.controls) { control in
                        controlView(control)
                    }
                }
                .padding(.horizontal, dialDrawerContentInset)
                .padding(.bottom, contentBottomPadding)
                .background {
                    GeometryReader { proxy in
                        Color.clear
                            .preference(key: DialMeasuredHeightKey.self, value: proxy.size.height)
                    }
                }
            }
            .frame(maxHeight: maxControlsHeight, alignment: .top)
        }
        .onPreferenceChange(DialMeasuredHeightKey.self) { newHeight in
            onMeasuredControlsHeight?(newHeight)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 6) {
            Button {
                panel.savePreset(named: panel.nextPresetName)
            } label: {
                Image(systemName: "slider.horizontal.below.square.and.square.filled")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DialTheme.textLabel)
                    .frame(width: 36, height: 36)
                    .background(DialRowBackground(cornerRadius: 8))
            }
            .buttonStyle(.plain)

            Menu {
                Button("Version 1") {
                    panel.clearActivePreset()
                }

                if !panel.presets.isEmpty {
                    Divider()
                }

                ForEach(panel.presets) { preset in
                    Button(preset.name) {
                        panel.loadPreset(id: preset.id)
                    }
                }

                if let activePresetID = panel.activePresetID {
                    Divider()
                    Button("Delete Current Preset", role: .destructive) {
                        panel.deletePreset(id: activePresetID)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(activePresetName)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .opacity(0.6)
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DialTheme.textLabel)
                .frame(height: 36)
                .padding(.horizontal, 12)
                .background(DialRowBackground(cornerRadius: 8))
            }
            .buttonStyle(.plain)

            Button {
                copyTextToPasteboard(panel.copyInstructionText)
                copiedState = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                    copiedState = false
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: copiedState ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Copy")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(DialTheme.textLabel)
                .frame(height: 36)
                .padding(.horizontal, 12)
                .background(DialRowBackground(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
    }

    private func controlView(_ control: DialResolvedControl) -> AnyView {
        switch control.kind {
        case let .slider(slider):
            return AnyView(DialSliderRow(title: control.label, slider: slider))
        case let .toggle(toggle):
            return AnyView(DialToggleRow(title: control.label, isOn: Binding(get: toggle.get, set: toggle.set)))
        case let .text(text):
            return AnyView(DialTextRow(title: control.label, text: Binding(get: text.get, set: text.set), placeholder: text.placeholder ?? ""))
        case let .color(color):
            return AnyView(DialColorRow(title: control.label, hexValue: Binding(get: color.get, set: color.set)))
        case let .select(select):
            return AnyView(DialSelectRow(title: control.label, options: select.options, selection: Binding(get: select.get, set: select.set)))
        case let .spring(spring):
            return AnyView(DialSpringControl(title: control.label, control: spring))
        case let .transition(transition):
            return AnyView(DialTransitionControl(title: control.label, control: transition))
        case let .group(group):
            return AnyView(
                DialFolderSection(title: control.label, defaultOpen: !group.collapsed) {
                    ForEach(group.children) { child in
                        controlView(child)
                    }
                }
            )
        case let .action(action):
            return AnyView(DialActionButton(title: control.label, action: action.trigger))
        }
    }
}

struct DialPanelContainer: View {
    @ObservedObject var panel: AnyDialPanelBox
    let defaultOpen: Bool
    let inline: Bool

    @State private var isOpen: Bool

    init(panel: AnyDialPanelBox, defaultOpen: Bool, inline: Bool) {
        self.panel = panel
        self.defaultOpen = defaultOpen
        self.inline = inline
        self._isOpen = State(initialValue: inline || defaultOpen)
    }

    var body: some View {
        Group {
            if inline {
                expandedPanel
            } else if isOpen {
                expandedPanel
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .topTrailing)))
            } else {
                collapsedButton
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: isOpen)
    }

    private var collapsedButton: some View {
        Button {
            isOpen = true
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(DialTheme.textRoot)
                .frame(width: 42, height: 42)
                .background(
                    Circle()
                        .fill(DialTheme.panelBackground)
                )
                .overlay {
                    Circle()
                        .stroke(DialTheme.border, lineWidth: 1)
                }
                .shadow(color: DialTheme.shadow, radius: 18, y: 6)
        }
        .buttonStyle(.plain)
    }

    private var expandedPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)

            DialPanelControlsView(panel: panel)
        }
        .frame(width: 280)
        .background {
            DialPanelBackground(cornerRadius: 16)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(DialTheme.border, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: DialTheme.shadow, radius: 22, y: 8)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(panel.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DialTheme.textRoot)
                .lineLimit(1)

            Spacer(minLength: 0)

            if !inline {
                Button {
                    isOpen = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(DialTheme.textLabel)
                        .frame(width: 24, height: 24)
                        .background(DialRowBackground(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct DialRowBackground: View {
    var cornerRadius: CGFloat = 8

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(DialTheme.surface)
    }
}

private struct DialMeasuredHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct DialPanelBackground: View {
    var cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(DialTheme.panelBackground.opacity(0.94))
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.45))
            )
    }
}

private extension EdgeInsets {
    #if canImport(UIKit)
    var uiEdgeInsets: UIEdgeInsets {
        UIEdgeInsets(top: top, left: leading, bottom: bottom, right: trailing)
    }
    #endif
}

#if canImport(UIKit)
private struct DraggableFABOverlay: UIViewRepresentable {
    let containerSize: CGSize
    let safeAreaInsets: UIEdgeInsets
    let initialPosition: DialPosition
    @Binding var position: CGPoint?
    let action: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(position: $position, initialPosition: initialPosition, action: action)
    }

    func makeUIView(context: Context) -> FABContainerView {
        let view = FABContainerView()
        view.backgroundColor = .clear

        let fabView = context.coordinator.makeFABView()
        view.fabView = fabView
        view.addSubview(fabView)

        context.coordinator.containerView = view
        context.coordinator.fabView = fabView
        return view
    }

    func updateUIView(_ uiView: FABContainerView, context: Context) {
        let effectiveSize = uiView.bounds.size == .zero ? containerSize : uiView.bounds.size
        context.coordinator.containerSize = effectiveSize == .zero ? containerSize : effectiveSize
        context.coordinator.safeAreaInsets = safeAreaInsets
        context.coordinator.initialPosition = initialPosition
        context.coordinator.updateLayout()
    }

    final class Coordinator: NSObject {
        private let diameter: CGFloat = 56
        private let horizontalMargin: CGFloat = 8
        private let topMargin: CGFloat = 8
        private let bottomMargin: CGFloat = 2
        private let position: Binding<CGPoint?>
        private let action: () -> Void

        weak var containerView: FABContainerView?
        weak var fabView: UIView?
        var containerSize: CGSize = .zero
        var safeAreaInsets: UIEdgeInsets = .zero
        var initialPosition: DialPosition
        private var panStartCenter: CGPoint = .zero
        private var currentCenter: CGPoint?
        private var lastContainerSize: CGSize = .zero
        private var isPanning = false

        init(position: Binding<CGPoint?>, initialPosition: DialPosition, action: @escaping () -> Void) {
            self.position = position
            self.initialPosition = initialPosition
            self.action = action
        }

        func makeFABView() -> UIView {
            let fab = UIView(frame: CGRect(x: 0, y: 0, width: diameter, height: diameter))
            fab.backgroundColor = UIColor(white: 0.13, alpha: 0.96)
            fab.layer.cornerRadius = diameter / 2
            fab.layer.cornerCurve = .continuous
            fab.layer.borderWidth = 1
            fab.layer.borderColor = UIColor.white.withAlphaComponent(0.10).cgColor
            fab.layer.shadowColor = UIColor.black.cgColor
            fab.layer.shadowOpacity = 0.25
            fab.layer.shadowRadius = 16
            fab.layer.shadowOffset = CGSize(width: 0, height: 4)
            fab.layer.shadowPath = UIBezierPath(ovalIn: fab.bounds).cgPath

            let imageView = UIImageView(image: UIImage(systemName: "slider.horizontal.3"))
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.tintColor = .white
            imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
            fab.addSubview(imageView)

            NSLayoutConstraint.activate([
                imageView.centerXAnchor.constraint(equalTo: fab.centerXAnchor),
                imageView.centerYAnchor.constraint(equalTo: fab.centerYAnchor)
            ])

            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            tap.require(toFail: pan)
            fab.addGestureRecognizer(tap)
            fab.addGestureRecognizer(pan)

            return fab
        }

        func updateLayout() {
            guard let fabView else { return }
            fabView.bounds = CGRect(x: 0, y: 0, width: diameter, height: diameter)
            fabView.layer.shadowPath = UIBezierPath(ovalIn: fabView.bounds).cgPath
            let effectiveContainerSize = resolvedContainerSize()
            containerSize = effectiveContainerSize

            let defaultCenter = dialDefaultFABCenter(
                for: initialPosition,
                in: effectiveContainerSize,
                safeAreaInsets: safeAreaInsets,
                diameter: diameter,
                horizontalMargin: horizontalMargin,
                topMargin: topMargin,
                bottomMargin: bottomMargin
            )
            let targetCenter = dialClampedFABCenter(
                currentCenter ?? position.wrappedValue ?? defaultCenter,
                in: effectiveContainerSize,
                safeAreaInsets: safeAreaInsets,
                diameter: diameter,
                horizontalMargin: horizontalMargin,
                topMargin: topMargin,
                bottomMargin: bottomMargin
            )
            let sizeChanged = lastContainerSize != effectiveContainerSize

            if fabView.center == .zero || sizeChanged || (!isPanning && distance(from: fabView.center, to: targetCenter) > 0.5) {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                fabView.center = targetCenter
                CATransaction.commit()
            }

            currentCenter = targetCenter
            lastContainerSize = effectiveContainerSize
        }

        @objc private func handleTap() {
            action()
        }

        @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
            guard let fabView, let containerView else { return }

            let translation = recognizer.translation(in: containerView)
            let effectiveContainerSize = resolvedContainerSize(using: containerView)
            containerSize = effectiveContainerSize

            switch recognizer.state {
            case .began:
                isPanning = true
                panStartCenter = fabView.center
                currentCenter = fabView.center
                animateDragging(true, on: fabView)

            case .changed:
                let nextCenter = dialClampedFABCenter(
                    CGPoint(x: panStartCenter.x + translation.x, y: panStartCenter.y + translation.y),
                    in: effectiveContainerSize,
                    safeAreaInsets: safeAreaInsets,
                    diameter: diameter,
                    horizontalMargin: horizontalMargin,
                    topMargin: topMargin,
                    bottomMargin: bottomMargin
                )
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                fabView.center = nextCenter
                CATransaction.commit()
                currentCenter = nextCenter

            case .ended, .cancelled, .failed:
                let finalCenter = dialClampedFABCenter(
                    CGPoint(x: panStartCenter.x + translation.x, y: panStartCenter.y + translation.y),
                    in: effectiveContainerSize,
                    safeAreaInsets: safeAreaInsets,
                    diameter: diameter,
                    horizontalMargin: horizontalMargin,
                    topMargin: topMargin,
                    bottomMargin: bottomMargin
                )
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                fabView.center = finalCenter
                CATransaction.commit()
                currentCenter = finalCenter
                isPanning = false
                DispatchQueue.main.async {
                    self.position.wrappedValue = finalCenter
                }
                animateDragging(false, on: fabView)

            default:
                break
            }
        }

        private func animateDragging(_ dragging: Bool, on view: UIView) {
            UIView.animate(withDuration: 0.16, delay: 0, options: [.beginFromCurrentState, .curveEaseOut]) {
                view.transform = dragging ? CGAffineTransform(scaleX: 1.24, y: 1.24) : .identity
                view.layer.shadowOpacity = dragging ? 0.68 : 0.25
                view.layer.shadowRadius = dragging ? 28 : 16
                view.layer.shadowOffset = dragging ? .zero : CGSize(width: 0, height: 4)
            }
        }

        private func resolvedContainerSize(using view: UIView? = nil) -> CGSize {
            let liveSize = view?.bounds.size ?? containerView?.bounds.size ?? .zero
            return liveSize == .zero ? containerSize : liveSize
        }

        private func distance(from lhs: CGPoint, to rhs: CGPoint) -> CGFloat {
            hypot(lhs.x - rhs.x, lhs.y - rhs.y)
        }
    }
}

private final class FABContainerView: UIView {
    weak var fabView: UIView?

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        guard let fabView else { return false }
        let hitFrame = fabView.frame.insetBy(dx: -24, dy: -24)
        return hitFrame.contains(point)
    }
}
#endif

private struct DialFolderSection<Content: View>: View {
    let title: String
    let defaultOpen: Bool
    let content: Content

    @State private var isExpanded: Bool

    init(title: String, defaultOpen: Bool, @ViewBuilder content: () -> Content) {
        self.title = title
        self.defaultOpen = defaultOpen
        self.content = content()
        self._isExpanded = State(initialValue: defaultOpen)
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.88)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DialTheme.textSection)

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DialTheme.textLabel.opacity(0.8))
                        .rotationEffect(.degrees(isExpanded ? 0 : 180))
                }
                .frame(height: 36)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 6) {
                    content
                }
                .padding(.bottom, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(DialTheme.borderSoft)
                .frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(DialTheme.borderSoft)
                .frame(height: 1)
        }
        .padding(.vertical, 4)
        .onChange(of: defaultOpen) { _, newValue in
            isExpanded = newValue
        }
    }
}

private struct DialSegmentOption<Value: Hashable>: Identifiable {
    let value: Value
    let label: String

    var id: String { label }
}

private struct DialSegmentedControl<Value: Hashable>: View {
    let options: [DialSegmentOption<Value>]
    @Binding var selection: Value

    var body: some View {
        GeometryReader { proxy in
            let segmentWidth = proxy.size.width / CGFloat(max(options.count, 1))
            let selectedIndex = CGFloat(options.firstIndex(where: { $0.value == selection }) ?? 0)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.clear)

                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(DialTheme.surfaceActive)
                    .frame(width: max(segmentWidth - 4, 0), height: proxy.size.height - 4)
                    .offset(x: selectedIndex * segmentWidth + 2)

                HStack(spacing: 0) {
                    ForEach(options) { option in
                        Button {
                            withAnimation(.spring(response: 0.22, dampingFraction: 0.84)) {
                                selection = option.value
                            }
                        } label: {
                            Text(option.label)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(selection == option.value ? Color.white.opacity(0.82) : DialTheme.textLabel)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(2)
            }
        }
        .frame(width: CGFloat(max(options.count, 2)) * 56, height: 32)
        .background(DialRowBackground(cornerRadius: 8))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct DialSegmentedRow<Value: Hashable>: View {
    let title: String
    let options: [DialSegmentOption<Value>]
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DialTheme.textLabel)

            Spacer(minLength: 8)

            DialSegmentedControl(options: options, selection: $selection)
        }
        .frame(height: 36)
        .padding(.leading, 12)
        .padding(.trailing, 10)
        .background(DialRowBackground(cornerRadius: 8))
    }
}

private struct DialToggleRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        DialSegmentedRow(
            title: title,
            options: [
                .init(value: false, label: "Off"),
                .init(value: true, label: "On")
            ],
            selection: $isOn
        )
    }
}

private struct DialSelectRow: View {
    let title: String
    let options: [DialOption]
    @Binding var selection: String

    private var selectedLabel: String {
        options.first(where: { $0.value == selection })?.label ?? selection
    }

    var body: some View {
        Menu {
            ForEach(options) { option in
                Button(option.label) {
                    selection = option.value
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DialTheme.textLabel)

                Spacer(minLength: 10)

                Text(selectedLabel)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DialTheme.textLabel)
                    .lineLimit(1)

                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DialTheme.textLabel.opacity(0.7))
            }
            .frame(height: 36)
            .padding(.horizontal, 12)
            .background(DialRowBackground(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

private struct DialTextRow: View {
    let title: String
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DialTheme.textLabel)

            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.words)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DialTheme.textLabel)
                .tint(.white)
        }
        .frame(height: 36)
        .padding(.horizontal, 12)
        .background(DialRowBackground(cornerRadius: 8))
    }
}

private struct DialColorRow: View {
    let title: String
    @Binding var hexValue: String

    @State private var draft: String

    init(title: String, hexValue: Binding<String>) {
        self.title = title
        self._hexValue = hexValue
        self._draft = State(initialValue: hexValue.wrappedValue.uppercased())
    }

    private var pickerBinding: Binding<Color> {
        Binding {
            dialColor(from: hexValue) ?? .white
        } set: { newColor in
            if let hex = dialHexString(from: newColor, prefersAlphaOutput: dialHexUsesExplicitAlpha(hexValue)) {
                hexValue = hex
                draft = hex
            }
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DialTheme.textLabel)

            Spacer(minLength: 8)

            TextField("#FFFFFF", text: $draft)
                .textInputAutocapitalization(.characters)
                .disableAutocorrection(true)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(DialTheme.textLabel)
                .frame(width: 88)
                .onChange(of: hexValue) { _, newValue in
                    draft = newValue.uppercased()
                }
                .onSubmit(commitDraft)

            ColorPicker("", selection: pickerBinding, supportsOpacity: true)
                .labelsHidden()
                .frame(width: 24, height: 24)
        }
        .frame(height: 36)
        .padding(.horizontal, 12)
        .background(DialRowBackground(cornerRadius: 8))
    }

    private func commitDraft() {
        let filtered = String(draft.uppercased().filter { $0.isHexDigit || $0 == "#" })
        let normalized: String
        if filtered.isEmpty {
            normalized = hexValue
        } else if filtered.first == "#" {
            normalized = String(filtered.prefix(9))
        } else {
            normalized = "#" + String(filtered.prefix(8))
        }

        if dialIsValidHexColor(normalized) {
            hexValue = normalized
            draft = normalized
        } else {
            draft = hexValue.uppercased()
        }
    }
}

private struct DialSliderRow: View {
    let title: String
    let slider: DialResolvedSlider

    @State private var isEditing = false
    @State private var draft = ""
    @State private var isInteracting = false
    @State private var lastHapticValue: Double?
    #if canImport(UIKit)
    @State private var feedbackGenerator: UISelectionFeedbackGenerator?
    #endif

    private var value: Double {
        slider.get()
    }

    private var progress: CGFloat {
        guard slider.range.upperBound > slider.range.lowerBound else { return 0 }
        return CGFloat((value - slider.range.lowerBound) / (slider.range.upperBound - slider.range.lowerBound))
    }

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)

            ZStack(alignment: .leading) {
                DialRowBackground(cornerRadius: 8)

                HStack(spacing: 0) {
                    ForEach(0..<11, id: \.self) { _ in
                        Capsule()
                            .fill(Color.white.opacity(isInteracting ? 0.15 : 0))
                            .frame(width: 1, height: 8)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 8)

                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(isInteracting ? 0.14 : 0.10))
                    .frame(width: width * progress)

                RoundedRectangle(cornerRadius: 99, style: .continuous)
                    .fill(Color.white.opacity(0.8))
                    .frame(width: 3, height: 20)
                    .offset(x: max(width * progress - 2, 6))

                HStack(spacing: 12) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DialTheme.textLabel)

                    Spacer(minLength: 0)

                    if isEditing {
                        TextField("", text: $draft)
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.white)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 68)
                            .onSubmit(commitDraft)
                    } else {
                        Button {
                            draft = value.formatted(step: slider.step)
                            isEditing = true
                        } label: {
                            Text(formattedValue)
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundStyle(isInteracting ? Color.white : DialTheme.textLabel)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
            }
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if !isInteracting {
                            beginInteraction()
                        }
                        updateValue(at: gesture.location.x, width: width)
                    }
                    .onEnded { _ in
                        endInteraction()
                    }
            )
        }
        .frame(height: 36)
    }

    private var formattedValue: String {
        if let unit = slider.unit {
            return "\(value.formatted(step: slider.step))\(unit)"
        }
        return value.formatted(step: slider.step)
    }

    private func updateValue(at x: CGFloat, width: CGFloat) {
        let clampedX = min(max(x, 0), width)
        let fraction = clampedX / width
        let raw = slider.range.lowerBound + Double(fraction) * (slider.range.upperBound - slider.range.lowerBound)
        let snapped = dialSnappedSliderValue(raw, range: slider.range, step: slider.step)

        if dialShouldEmitSliderHaptic(previousValue: lastHapticValue, nextValue: snapped) {
            #if canImport(UIKit)
            feedbackGenerator?.selectionChanged()
            feedbackGenerator?.prepare()
            #endif
        }

        lastHapticValue = snapped
        slider.set(snapped)
    }

    private func commitDraft() {
        defer { isEditing = false }
        guard let parsed = Double(draft) else {
            draft = value.formatted(step: slider.step)
            return
        }
        slider.set(parsed)
        draft = value.formatted(step: slider.step)
    }

    private func beginInteraction() {
        isEditing = false
        isInteracting = true
        lastHapticValue = value
        #if canImport(UIKit)
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        feedbackGenerator = generator
        #endif
    }

    private func endInteraction() {
        isInteracting = false
        lastHapticValue = nil
        #if canImport(UIKit)
        feedbackGenerator = nil
        #endif
    }
}

private struct DialActionButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Spacer(minLength: 0)
            }
            .foregroundStyle(DialTheme.textLabel)
            .frame(height: 36)
            .padding(.horizontal, 12)
            .background(DialRowBackground(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

private struct DialSpringControl: View {
    let title: String
    let control: DialResolvedSpring

    var body: some View {
        DialFolderSection(title: title, defaultOpen: true) {
            SpringVisualization(spring: control.get())
                .frame(height: 140)

            DialSegmentedRow(
                title: "Type",
                options: DialSpringEditorMode.allCases.map { .init(value: $0, label: $0.label) },
                selection: Binding(
                    get: { control.get().editorMode },
                    set: { mode in
                        switch mode {
                        case .simple:
                            control.set(control.get().updatingTime())
                        case .advanced:
                            control.set(control.get().updatingPhysics())
                        }
                    }
                )
            )

            switch control.get() {
            case let .time(duration, bounce):
                DialSliderRow(title: "Duration", slider: slider(range: 0.1...1, step: 0.05, unit: "s", get: { duration }, set: { control.set(control.get().updatingTime(duration: $0)) }))
                DialSliderRow(title: "Bounce", slider: slider(range: 0...1, step: 0.05, get: { bounce }, set: { control.set(control.get().updatingTime(bounce: $0)) }))
            case let .physics(stiffness, damping, mass):
                DialSliderRow(title: "Stiffness", slider: slider(range: 1...1000, step: 1, get: { stiffness }, set: { control.set(control.get().updatingPhysics(stiffness: $0)) }))
                DialSliderRow(title: "Damping", slider: slider(range: 1...100, step: 1, get: { damping }, set: { control.set(control.get().updatingPhysics(damping: $0)) }))
                DialSliderRow(title: "Mass", slider: slider(range: 0.1...10, step: 0.1, get: { mass }, set: { control.set(control.get().updatingPhysics(mass: $0)) }))
            }
        }
    }
}

private struct DialTransitionControl: View {
    let title: String
    let control: DialResolvedTransition

    var body: some View {
        DialFolderSection(title: title, defaultOpen: true) {
            switch control.get() {
            case let .easing(_, bezier):
                EasingVisualization(bezier: bezier)
                    .frame(height: 140)
            case let .spring(spring):
                SpringVisualization(spring: spring)
                    .frame(height: 140)
            }

            DialSegmentedRow(
                title: "Type",
                options: DialTransitionMode.allCases.map { .init(value: $0, label: $0.label) },
                selection: Binding(
                    get: { control.get().mode },
                    set: { mode in
                        control.set(control.get().switching(to: mode))
                    }
                )
            )

            switch control.get() {
            case let .easing(duration, bezier):
                DialSliderRow(title: "x1", slider: slider(range: 0...1, step: 0.01, get: { bezier.x1 }, set: { updateBezier(x1: $0) }))
                DialSliderRow(title: "y1", slider: slider(range: -1...2, step: 0.01, get: { bezier.y1 }, set: { updateBezier(y1: $0) }))
                DialSliderRow(title: "x2", slider: slider(range: 0...1, step: 0.01, get: { bezier.x2 }, set: { updateBezier(x2: $0) }))
                DialSliderRow(title: "y2", slider: slider(range: -1...2, step: 0.01, get: { bezier.y2 }, set: { updateBezier(y2: $0) }))
                DialSliderRow(title: "Duration", slider: slider(range: 0.1...2, step: 0.05, unit: "s", get: { duration }, set: { updateDuration($0) }))
                DialBezierRow(bezier: bezier) { newBezier in
                    control.set(.easing(duration: duration, bezier: newBezier))
                }
            case let .spring(spring):
                switch spring {
                case let .time(duration, bounce):
                    DialSliderRow(title: "Duration", slider: slider(range: 0.1...1, step: 0.05, unit: "s", get: { duration }, set: { updateSpringTime(duration: $0) }))
                    DialSliderRow(title: "Bounce", slider: slider(range: 0...1, step: 0.05, get: { bounce }, set: { updateSpringTime(bounce: $0) }))
                case let .physics(stiffness, damping, mass):
                    DialSliderRow(title: "Stiffness", slider: slider(range: 1...1000, step: 10, get: { stiffness }, set: { updateSpringPhysics(stiffness: $0) }))
                    DialSliderRow(title: "Damping", slider: slider(range: 1...100, step: 1, get: { damping }, set: { updateSpringPhysics(damping: $0) }))
                    DialSliderRow(title: "Mass", slider: slider(range: 0.1...10, step: 0.1, get: { mass }, set: { updateSpringPhysics(mass: $0) }))
                }
            }
        }
    }

    private func updateDuration(_ duration: Double) {
        if case let .easing(_, bezier) = control.get() {
            control.set(.easing(duration: duration, bezier: bezier))
        }
    }

    private func updateBezier(x1: Double? = nil, y1: Double? = nil, x2: Double? = nil, y2: Double? = nil) {
        guard case let .easing(duration, bezier) = control.get() else { return }
        control.set(
            .easing(
                duration: duration,
                bezier: DialBezier(
                    x1: x1 ?? bezier.x1,
                    y1: y1 ?? bezier.y1,
                    x2: x2 ?? bezier.x2,
                    y2: y2 ?? bezier.y2
                )
            )
        )
    }

    private func updateSpringTime(duration: Double? = nil, bounce: Double? = nil) {
        switch control.get() {
        case .easing:
            break
        case let .spring(spring):
            control.set(.spring(spring.updatingTime(duration: duration, bounce: bounce)))
        }
    }

    private func updateSpringPhysics(stiffness: Double? = nil, damping: Double? = nil, mass: Double? = nil) {
        switch control.get() {
        case .easing:
            break
        case let .spring(spring):
            control.set(.spring(spring.updatingPhysics(stiffness: stiffness, damping: damping, mass: mass)))
        }
    }
}

private struct DialBezierRow: View {
    let bezier: DialBezier
    let onChange: (DialBezier) -> Void

    @State private var draft: String
    @State private var isEditing = false

    init(bezier: DialBezier, onChange: @escaping (DialBezier) -> Void) {
        self.bezier = bezier
        self.onChange = onChange
        self._draft = State(initialValue: Self.format(bezier))
    }

    var body: some View {
        HStack(spacing: 12) {
            Text("Bezier")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DialTheme.textLabel)

            TextField("0.25, 0.1, 0.25, 1", text: $draft)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .multilineTextAlignment(.trailing)
                .foregroundStyle(DialTheme.textLabel)
                .onTapGesture {
                    isEditing = true
                }
                .onSubmit(commit)
                .onChange(of: Self.format(bezier)) { _, newValue in
                    guard !isEditing else { return }
                    draft = newValue
                }
        }
        .frame(height: 36)
        .padding(.horizontal, 12)
        .background(DialRowBackground(cornerRadius: 8))
    }

    private func commit() {
        defer { isEditing = false }
        let parts = draft.split(separator: ",").map { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count == 4,
              let x1 = parts[0],
              let y1 = parts[1],
              let x2 = parts[2],
              let y2 = parts[3] else {
            draft = Self.format(bezier)
            return
        }
        onChange(DialBezier(x1: x1, y1: y1, x2: x2, y2: y2))
        draft = Self.format(DialBezier(x1: x1, y1: y1, x2: x2, y2: y2))
    }

    private static func format(_ bezier: DialBezier) -> String {
        [bezier.x1, bezier.y1, bezier.x2, bezier.y2]
            .map { $0.formatted(step: 0.01) }
            .joined(separator: ", ")
    }
}

private struct SpringVisualization: View {
    let spring: DialSpring

    var body: some View {
        Canvas { context, size in
            let width = size.width
            let height = size.height
            let points = generateCurve(in: width, height: height)

            for index in 1..<4 {
                let horizontalY = (height / 4) * CGFloat(index)
                let verticalX = (width / 4) * CGFloat(index)

                var horizontal = Path()
                horizontal.move(to: CGPoint(x: 0, y: horizontalY))
                horizontal.addLine(to: CGPoint(x: width, y: horizontalY))
                context.stroke(horizontal, with: .color(Color.white.opacity(0.08)), lineWidth: 1)

                var vertical = Path()
                vertical.move(to: CGPoint(x: verticalX, y: 0))
                vertical.addLine(to: CGPoint(x: verticalX, y: height))
                context.stroke(vertical, with: .color(Color.white.opacity(0.08)), lineWidth: 1)
            }

            var midpoint = Path()
            midpoint.move(to: CGPoint(x: 0, y: height / 2))
            midpoint.addLine(to: CGPoint(x: width, y: height / 2))
            context.stroke(midpoint, with: .color(Color.white.opacity(0.15)), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

            var curve = Path()
            curve.addLines(points)
            context.stroke(curve, with: .color(Color.white.opacity(0.62)), lineWidth: 2)
        }
        .background(DialRowBackground(cornerRadius: 8))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func generateCurve(in width: CGFloat, height: CGFloat) -> [CGPoint] {
        let physics = spring.resolvedPhysics
        let steps = 100
        let duration = 2.0
        let dt = duration / Double(steps)

        var position = 0.0
        var velocity = 0.0
        var rawValues: [(time: Double, value: Double)] = []

        for index in 0...steps {
            let time = Double(index) * dt
            rawValues.append((time: time, value: position))

            let target = 1.0
            let springForce = -physics.stiffness * (position - target)
            let dampingForce = -physics.damping * velocity
            let acceleration = (springForce + dampingForce) / physics.mass

            velocity += acceleration * dt
            position += velocity * dt
        }

        let values = rawValues.map(\.value)
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 1
        let valueRange = max(maxValue - minValue, 0.001)

        return rawValues.map { point in
            let x = CGFloat(point.time / duration) * width
            let normalized = (point.value - minValue) / valueRange
            let y = height - CGFloat(normalized) * height * 0.6 - height * 0.2
            return CGPoint(x: x, y: y)
        }
    }
}

private struct EasingVisualization: View {
    let bezier: DialBezier

    var body: some View {
        Canvas { context, size in
            for index in 1..<4 {
                let horizontalY = (size.height / 4) * CGFloat(index)
                let verticalX = (size.width / 4) * CGFloat(index)

                var horizontal = Path()
                horizontal.move(to: CGPoint(x: 0, y: horizontalY))
                horizontal.addLine(to: CGPoint(x: size.width, y: horizontalY))
                context.stroke(horizontal, with: .color(Color.white.opacity(0.08)), lineWidth: 1)

                var vertical = Path()
                vertical.move(to: CGPoint(x: verticalX, y: 0))
                vertical.addLine(to: CGPoint(x: verticalX, y: size.height))
                context.stroke(vertical, with: .color(Color.white.opacity(0.08)), lineWidth: 1)
            }

            var axis = Path()
            axis.move(to: .init(x: 0, y: size.height))
            axis.addLine(to: .init(x: size.width, y: 0))
            context.stroke(axis, with: .color(Color.white.opacity(0.15)), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

            var curve = Path()
            let points = easingPoints(in: size)
            curve.addLines(points)
            context.stroke(curve, with: .color(Color.white.opacity(0.62)), lineWidth: 2)
        }
        .background(DialRowBackground(cornerRadius: 8))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func easingPoints(in size: CGSize) -> [CGPoint] {
        (0...80).map { index in
            let t = CGFloat(index) / 80
            let point = cubicPoint(for: t)
            return CGPoint(x: point.x * size.width, y: size.height - point.y * size.height)
        }
    }

    private func cubicPoint(for t: CGFloat) -> CGPoint {
        CGPoint(
            x: cubic(t, 0, CGFloat(bezier.x1), CGFloat(bezier.x2), 1),
            y: cubic(t, 0, CGFloat(bezier.y1), CGFloat(bezier.y2), 1)
        )
    }

    private func cubic(_ t: CGFloat, _ a: CGFloat, _ b: CGFloat, _ c: CGFloat, _ d: CGFloat) -> CGFloat {
        let mt = 1 - t
        return mt * mt * mt * a
            + 3 * mt * mt * t * b
            + 3 * mt * t * t * c
            + t * t * t * d
    }
}

private func slider(
    range: ClosedRange<Double>,
    step: Double,
    unit: String? = nil,
    get: @escaping () -> Double,
    set: @escaping (Double) -> Void
) -> DialResolvedSlider {
    DialResolvedSlider(range: range, step: step, unit: unit, get: get, set: set)
}

private func copyTextToPasteboard(_ text: String) {
    #if canImport(UIKit)
    UIPasteboard.general.string = text
    #endif
}

private extension Double {
    func formatted(step: Double) -> String {
        dialFormattedNumber(self, step: step)
    }
}

package func dialHexUsesExplicitAlpha(_ hex: String) -> Bool {
    let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
    return cleaned.count == 8
}

package func dialColor(from hex: String) -> Color? {
    let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
    let length = cleaned.count

    guard length == 3 || length == 6 || length == 8 else {
        return nil
    }

    let expanded: String
    if length == 3 {
        expanded = cleaned.map { "\($0)\($0)" }.joined()
    } else {
        expanded = cleaned
    }

    var hexValue: UInt64 = 0
    guard Scanner(string: expanded).scanHexInt64(&hexValue) else {
        return nil
    }

    let red, green, blue, alpha: Double
    switch expanded.count {
    case 6:
        red = Double((hexValue >> 16) & 0xFF) / 255
        green = Double((hexValue >> 8) & 0xFF) / 255
        blue = Double(hexValue & 0xFF) / 255
        alpha = 1
    case 8:
        red = Double((hexValue >> 24) & 0xFF) / 255
        green = Double((hexValue >> 16) & 0xFF) / 255
        blue = Double((hexValue >> 8) & 0xFF) / 255
        alpha = Double(hexValue & 0xFF) / 255
    default:
        return nil
    }

    return Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
}

package func dialHexString(from color: Color, prefersAlphaOutput: Bool = false) -> String? {
    #if canImport(UIKit)
    let uiColor = UIColor(color)
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0

    guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
        return nil
    }

    let redValue = Int(round(red * 255))
    let greenValue = Int(round(green * 255))
    let blueValue = Int(round(blue * 255))
    let alphaValue = Int(round(alpha * 255))

    if prefersAlphaOutput || alphaValue < 255 {
        return String(format: "#%02X%02X%02X%02X", redValue, greenValue, blueValue, alphaValue)
    }

    return String(format: "#%02X%02X%02X", redValue, greenValue, blueValue)
    #else
    return nil
    #endif
}
