import Combine
import Foundation

package protocol DialVersionPanel: AnyObject {
    var baseVersionName: String { get }
    var presetSummaries: [DialPresetSummary] { get }
    var activePresetID: UUID? { get }
    var nextPresetName: String { get }
    var versionSaveError: DialVersionSaveError? { get }
    @discardableResult func savePreset(named name: String) -> Bool
    func loadPreset(id: UUID)
    func clearActivePreset()
    func deletePreset(id: UUID)
    func renameVersion(id: UUID?, name: String)
    func thumbnail(for id: UUID?) -> Data?
    func setThumbnail(_ data: Data, for id: UUID?)
}

extension DialPanelState: DialVersionPanel {}

package final class AnyDialPanelBox: ObservableObject, Identifiable {
    package let id: UUID
    package let objectWillChange = ObservableObjectPublisher()

    private var accordionExpandedStates: [String: Bool] = [:]
    private var nameProvider: (() -> String)?
    private var controlsProvider: (() -> [DialResolvedControl])?
    private weak var versions: (any DialVersionPanel)?
    private var copyTextProvider: (() -> String)?
    private var cancellable: AnyCancellable?

    package init(id: UUID) {
        self.id = id
    }

    package var name: String { nameProvider?() ?? "" }
    package var controls: [DialResolvedControl] { controlsProvider?() ?? [] }
    package var presets: [DialPresetSummary] { versions?.presetSummaries ?? [] }
    package var activePresetID: UUID? { versions?.activePresetID }
    package var nextPresetName: String { versions?.nextPresetName ?? "V2" }
    package var baseVersionName: String { versions?.baseVersionName ?? "V1" }
    package var versionSaveError: DialVersionSaveError? { versions?.versionSaveError }
    package var copyInstructionText: String { copyTextProvider?() ?? "" }

    package func accordionExpanded(for id: String, default defaultValue: Bool) -> Bool {
        if let stored = accordionExpandedStates[id] {
            return stored
        }

        accordionExpandedStates[id] = defaultValue
        return defaultValue
    }

    package func setAccordionExpanded(_ isExpanded: Bool, for id: String) {
        guard accordionExpandedStates[id] != isExpanded else {
            return
        }

        accordionExpandedStates[id] = isExpanded
        objectWillChange.send()
    }

    package func pruneAccordionExpanded(validIDs: Set<String>) {
        accordionExpandedStates = accordionExpandedStates.filter { validIDs.contains($0.key) }
    }

    @discardableResult
    package func savePreset(named name: String) -> Bool {
        versions?.savePreset(named: name) ?? false
    }

    package func loadPreset(id: UUID) {
        versions?.loadPreset(id: id)
    }

    package func clearActivePreset() {
        versions?.clearActivePreset()
    }

    package func deletePreset(id: UUID) {
        versions?.deletePreset(id: id)
    }

    package func renameVersion(id: UUID?, name: String) { versions?.renameVersion(id: id, name: name) }
    package func thumbnail(for id: UUID?) -> Data? { versions?.thumbnail(for: id) }
    package func setThumbnail(_ data: Data, for id: UUID?) { versions?.setThumbnail(data, for: id) }

    package func bind<Model>(to state: DialPanelState<Model>) where Model: Codable & Equatable {
        nameProvider = { [weak state] in state?.name ?? "" }
        controlsProvider = { [weak state] in state?.resolvedControls() ?? [] }
        versions = state
        copyTextProvider = { [weak state] in state?.copyInstructionText() ?? "" }
        cancellable = state.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }
}

public final class DialStore: ObservableObject {
    public static let shared = DialStore()

    @Published package private(set) var panels: [AnyDialPanelBox] = []

    private init() {}

    package func register(_ panel: AnyDialPanelBox) {
        if let index = panels.firstIndex(where: { $0.id == panel.id }) {
            panels[index] = panel
        } else {
            panels.append(panel)
        }
    }

    package func unregister(id: UUID) {
        panels.removeAll { $0.id == id }
    }

    package func resetForTesting() {
        panels.removeAll()
    }
}
