import Combine
import Foundation

package final class AnyDialPanelBox: ObservableObject, Identifiable {
    package let id: UUID
    package let objectWillChange = ObservableObjectPublisher()

    private var nameProvider: (() -> String)?
    private var controlsProvider: (() -> [DialResolvedControl])?
    private var presetsProvider: (() -> [DialPresetSummary])?
    private var activePresetProvider: (() -> UUID?)?
    private var nextPresetNameProvider: (() -> String)?
    private var savePresetHandler: ((String) -> Void)?
    private var loadPresetHandler: ((UUID) -> Void)?
    private var clearPresetHandler: (() -> Void)?
    private var deletePresetHandler: ((UUID) -> Void)?
    private var copyTextProvider: (() -> String)?
    private var cancellable: AnyCancellable?

    package init(id: UUID) {
        self.id = id
    }

    package var name: String { nameProvider?() ?? "" }
    package var controls: [DialResolvedControl] { controlsProvider?() ?? [] }
    package var presets: [DialPresetSummary] { presetsProvider?() ?? [] }
    package var activePresetID: UUID? { activePresetProvider?() }
    package var nextPresetName: String { nextPresetNameProvider?() ?? "Version 2" }
    package var copyInstructionText: String { copyTextProvider?() ?? "" }

    package func savePreset(named name: String) {
        savePresetHandler?(name)
    }

    package func loadPreset(id: UUID) {
        loadPresetHandler?(id)
    }

    package func clearActivePreset() {
        clearPresetHandler?()
    }

    package func deletePreset(id: UUID) {
        deletePresetHandler?(id)
    }

    package func bind<Model>(to state: DialPanelState<Model>) where Model: Codable & Equatable {
        nameProvider = { [weak state] in state?.name ?? "" }
        controlsProvider = { [weak state] in state?.resolvedControls() ?? [] }
        presetsProvider = { [weak state] in state?.presetSummaries ?? [] }
        activePresetProvider = { [weak state] in state?.activePresetID }
        nextPresetNameProvider = { [weak state] in state?.nextPresetName ?? "Version 2" }
        savePresetHandler = { [weak state] name in state?.savePreset(named: name) }
        loadPresetHandler = { [weak state] id in state?.loadPreset(id: id) }
        clearPresetHandler = { [weak state] in state?.clearActivePreset() }
        deletePresetHandler = { [weak state] id in state?.deletePreset(id: id) }
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
