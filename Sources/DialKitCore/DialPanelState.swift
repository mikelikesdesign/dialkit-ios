import Combine
import Foundation

public final class DialPanelState<Model: Codable & Equatable>: ObservableObject, Identifiable {
    public let id: UUID

    @Published public var name: String
    /// Use `updateValues(_:)` for in-place edits to a class or nested reference.
    /// Those edits may not invoke this property's observer.
    @Published public var values: Model {
        didSet {
            guard !isApplyingInternalChange, values != oldValue else { return }
            synchronizeValues()
        }
    }
    @Published public private(set) var presets: [DialPreset<Model>]
    @Published public private(set) var activePresetID: UUID?
    @Published public private(set) var baseVersionName = "V1"
    @Published public private(set) var versionSaveError: DialVersionSaveError?

    public private(set) var controls: [DialControl<Model>]

    private var baseValues: Model
    private var thumbnails: [UUID?: Data] = [:]
    private var missingThumbnails: Set<UUID?> = []
    private let versionStorage: DialVersionStorage<Model>?
    private let copyValues: ((Model) throws -> Model)?
    private var isApplyingInternalChange = false
    private let onAction: ((String) -> Void)?
    package let panelBox: AnyDialPanelBox

    /// Supply `copyValues` when Codable does not preserve all version state.
    /// It must return an equivalent model with independent mutable references,
    /// without mutating the supplied model. Persisted archives still use Codable.
    public convenience init(
        id: UUID = UUID(),
        name: String,
        initial: Model,
        controls: [DialControl<Model>],
        persistKey: String? = nil,
        copyValues: ((Model) throws -> Model)? = nil,
        onAction: ((String) -> Void)? = nil
    ) {
        self.init(id: id, name: name, initial: initial, controls: controls,
                  versionStorage: persistKey.map { DialVersionStorage($0) },
                  copyValues: copyValues, onAction: onAction)
    }

    init(id: UUID = UUID(), name: String, initial: Model, controls: [DialControl<Model>],
         versionStorage: DialVersionStorage<Model>?, copyValues: ((Model) throws -> Model)? = nil,
         onAction: ((String) -> Void)? = nil) {
        self.id = id
        self.versionStorage = versionStorage
        self.copyValues = copyValues
        self.name = name
        self.controls = controls
        var normalizedInitial = initial
        for control in controls {
            control.node.normalize(current: &normalizedInitial, fallback: initial)
        }
        self.values = normalizedInitial
        self.baseValues = normalizedInitial
        self.presets = []
        self.activePresetID = nil
        self.onAction = onAction
        self.panelBox = AnyDialPanelBox(id: id)
        if let archive = versionStorage?.read() {
            baseVersionName = archive.baseName
            baseValues = archive.base
            presets = archive.presets
            activePresetID = presets.first { $0.id == archive.activeID }?.id
            applyInternalValueChange(activePresetID.flatMap { id in presets.first { $0.id == id }?.values } ?? baseValues)
            configure(initial: normalizedInitial, controls: controls)
        } else {
            versionStorage?.resetThumbnails()
        }
        self.panelBox.bind(to: self)
        DialStore.shared.register(panelBox)
    }

    deinit {
        DialStore.shared.unregister(id: id)
    }

    /// Commit a batch of programmatic edits, publish the model, invalidate the
    /// selected version's preview, and persist it when storage is enabled.
    /// Use this for class models and value models containing references.
    public func updateValues(_ update: (inout Model) -> Void) {
        var updated = values
        update(&updated)
        applyInternalValueChange(updated)
        synchronizeValues()
    }

    public func configure(
        name: String? = nil,
        initial: Model? = nil,
        controls: [DialControl<Model>]
    ) {
        objectWillChange.send()

        // Capture every version before even the fallback is normalized: it can
        // share objects with the base or the selected version.
        func captureValues(_ model: Model) -> (Model) -> Bool {
            let matches = controls.map { $0.node.valueMatcher(for: model) }
            return { current in matches.allSatisfy { $0(current) } }
        }
        let baseMatches = captureValues(baseValues)
        let presetMatches = presets.map { captureValues($0.values) }

        let fallbackSeed = initial ?? baseValues
        var normalizedFallback = fallbackSeed
        for control in controls {
            control.node.normalize(current: &normalizedFallback, fallback: fallbackSeed)
        }

        var nextValues = values
        for control in controls {
            control.node.normalize(current: &nextValues, fallback: normalizedFallback)
        }

        var nextBase = baseValues
        for control in controls {
            control.node.normalize(current: &nextBase, fallback: normalizedFallback)
        }

        var nextPresets = presets
        for index in nextPresets.indices {
            var candidate = nextPresets[index].values
            for control in controls {
                control.node.normalize(current: &candidate, fallback: normalizedFallback)
            }
            nextPresets[index].values = candidate
        }

        if baseValues != nextBase || !baseMatches(nextBase) { discardThumbnail(for: nil) }
        for ((previous, next), matches) in zip(zip(presets, nextPresets), presetMatches)
        where previous.values != next.values || !matches(next.values) {
            discardThumbnail(for: next.id)
        }
        self.controls = controls
        self.baseValues = nextBase
        self.presets = nextPresets
        if let name {
            self.name = name
        }
        applyInternalValueChange(nextValues)
        persistVersions()
    }

    /// Returns false and sets `versionSaveError` if copying fails or changes values.
    /// Existing versions and selection are left intact on failure.
    @discardableResult
    public func savePreset(named name: String) -> Bool {
        let frozen: Model
        do {
            frozen = try copyValues?(values) ?? copyVersionValues(values)
        } catch {
            versionSaveError = .copyFailed
            return false
        }
        guard frozen == values,
              controls.allSatisfy({ $0.node.valueMatcher(for: values)(frozen) }) else {
            versionSaveError = .copyChangedValues
            return false
        }
        versionSaveError = nil
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = trimmed.isEmpty ? nextPresetName : trimmed
        // A Codable model can contain class instances. Freeze the outgoing version
        // before the new version continues editing the live object graph.
        if let activePresetID, let index = presets.firstIndex(where: { $0.id == activePresetID }) {
            presets[index].values = frozen
        } else {
            baseValues = frozen
        }
        let preset = DialPreset(name: resolvedName, values: values)
        presets.append(preset)
        if let thumbnail = thumbnail(for: activePresetID) {
            setThumbnail(thumbnail, for: preset.id)
        }
        activePresetID = preset.id
        persistVersions()
        return true
    }

    public func loadPreset(id: UUID) {
        guard let preset = presets.first(where: { $0.id == id }) else { return }
        activePresetID = id
        applyInternalValueChange(preset.values)
        persistVersions()
    }

    public func clearActivePreset() {
        activePresetID = nil
        applyInternalValueChange(baseValues)
        persistVersions()
    }

    public func deletePreset(id: UUID) {
        guard presets.contains(where: { $0.id == id }) else { return }
        let isDeletingActivePreset = activePresetID == id
        discardThumbnail(for: id)
        presets.removeAll { $0.id == id }
        missingThumbnails.remove(id)
        if isDeletingActivePreset {
            clearActivePreset()
        } else {
            persistVersions()
        }
    }

    /// Pass nil to rename the editable base version.
    public func renameVersion(id: UUID?, name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let id {
            guard let index = presets.firstIndex(where: { $0.id == id }) else { return }
            presets[index].name = trimmed
        } else {
            baseVersionName = trimmed
        }
        persistVersions()
    }

    package func thumbnail(for id: UUID?) -> Data? {
        guard id == nil || presets.contains(where: { $0.id == id }) else { return nil }
        if thumbnails[id] == nil, !missingThumbnails.contains(id) {
            thumbnails[id] = versionStorage?.thumbnail(for: id)
            if thumbnails[id] == nil { missingThumbnails.insert(id) }
        }
        return thumbnails[id]
    }

    package func setThumbnail(_ data: Data, for id: UUID?) {
        guard data.count <= DialVersionStorage<Model>.thumbnailLimit,
              id == nil || presets.contains(where: { $0.id == id }),
              data != thumbnails[id] else { return }
        objectWillChange.send()
        missingThumbnails.remove(id)
        thumbnails[id] = data
        versionStorage?.setThumbnail(data, for: id)
    }

    private func discardThumbnail(for id: UUID?) {
        guard missingThumbnails.insert(id).inserted else { return }
        thumbnails[id] = nil
        versionStorage?.setThumbnail(nil, for: id)
    }

    private func persistVersions() {
        versionStorage?.write(.init(base: baseValues, baseName: baseVersionName, presets: presets, activeID: activePresetID))
    }

    public func copyInstructionText() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(values),
              let json = String(data: data, encoding: .utf8) else {
            return ""
        }

        return """
        Update the DialKit configuration for \"\(name)\" with these values:

        ```json
        \(json)
        ```

        Apply these values as the new defaults in the DialKit configuration.
        """
    }

    package var nextPresetName: String {
        let names = Set(presets.map(\.name))
        // Earlier iOS and web saves used "Version N". Keep their names and count them.
        let highest = names.compactMap { name -> Int? in
            guard let match = name.wholeMatch(of: #/(?:V|Version )([0-9]+)/#) else { return nil }
            return Int(match.1)
        }.max() ?? 1
        var next = highest == Int.max ? 2 : max(1, highest) + 1
        while names.contains("V\(next)") || baseVersionName == "V\(next)" {
            next = next == Int.max ? 2 : next + 1
        }
        return "V\(next)"
    }

    package var presetSummaries: [DialPresetSummary] {
        presets.map { DialPresetSummary(id: $0.id, name: $0.name) }
    }

    package func resolvedControls() -> [DialResolvedControl] {
        controls.flatMap { $0.node.resolve(state: self) }
    }

    func updateControlValue<Value: Equatable>(
        _ newValue: Value,
        getter: (Model) -> Value,
        setter: (inout Model, Value) -> Void
    ) {
        // Capture the field before mutation: oldValue can share references with values.
        let previous = getter(values)
        var updated = values
        setter(&updated, newValue)
        guard getter(updated) != previous else { return }
        applyInternalValueChange(updated)
        synchronizeValues()
    }

    package func triggerAction(path: String) {
        onAction?(path)
    }

    private func synchronizeValues() {
        discardThumbnail(for: activePresetID)
        if let activePresetID, let index = presets.firstIndex(where: { $0.id == activePresetID }) {
            presets[index].values = values
        } else {
            baseValues = values
        }
        persistVersions()
    }

    private func applyInternalValueChange(_ newValue: Model) {
        isApplyingInternalChange = true
        values = newValue
        isApplyingInternalChange = false
    }
}

/// Value models already have independent copies, including non-coded properties.
private func copyVersionValues<Model: Codable>(_ model: Model) throws -> Model {
    func containsReference(_ value: Any) -> Bool {
        let mirror = Mirror(reflecting: value)
        return mirror.displayStyle == .class || mirror.children.contains { containsReference($0.value) }
    }
    guard containsReference(model) else { return model }
    // Property lists require a collection at the root, even when Model encodes
    // itself as a single scalar value.
    let data = try PropertyListEncoder().encode([model])
    return try PropertyListDecoder().decode([Model].self, from: data)[0]
}
