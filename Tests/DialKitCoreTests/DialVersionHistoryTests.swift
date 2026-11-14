import XCTest
@testable import DialKitCore

@MainActor
final class DialVersionHistoryTests: XCTestCase {
    private struct Ink: Codable, Equatable { var color = "blue" }

    private final class InkObject: Codable, Equatable {
        var color = "blue"
        static func == (lhs: InkObject, rhs: InkObject) -> Bool { lhs.color == rhs.color }
    }

    private struct ReferenceInk: Codable, Equatable { var ink = InkObject() }

    func testSingleValueCodableReferenceVersionsStayIndependent() throws {
        final class ScalarModel: Codable, Equatable {
            var value: Double
            init(_ value: Double = 0.8) { self.value = value }
            init(from decoder: Decoder) throws {
                value = try decoder.singleValueContainer().decode(Double.self)
            }
            func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                try container.encode(value)
            }
            static func == (lhs: ScalarModel, rhs: ScalarModel) -> Bool { lhs.value == rhs.value }
        }
        let state = DialPanelState(name: "Scalar", initial: ScalarModel(), controls: [])
        XCTAssertTrue(state.savePreset(named: "First"))
        let first = try XCTUnwrap(state.activePresetID)
        state.updateValues { $0.value = 0.3 }
        XCTAssertTrue(state.savePreset(named: "Second"))
        state.updateValues { $0.value = 0.1 }
        state.loadPreset(id: first)
        XCTAssertEqual(state.values.value, 0.3)
        state.clearActivePreset()
        XCTAssertEqual(state.values.value, 0.8)
        XCTAssertNil(state.versionSaveError)
    }

    private final class RuntimeInk: Codable, Equatable {
        var color = "blue"
        var opacity = 0.8
        enum CodingKeys: String, CodingKey { case color }
        static func == (lhs: RuntimeInk, rhs: RuntimeInk) -> Bool {
            lhs.color == rhs.color && lhs.opacity == rhs.opacity
        }
        func independentCopy() -> RuntimeInk {
            let copy = RuntimeInk()
            copy.color = color
            copy.opacity = opacity
            return copy
        }
    }

    func testLossySnapshotFailsWithoutChangingVersionsOrPreviews() throws {
        let state = DialPanelState(name: "Runtime", initial: RuntimeInk(), controls: [])
        XCTAssertTrue(state.savePreset(named: "First"))
        let first = try XCTUnwrap(state.activePresetID)
        state.updateValues { $0.opacity = 0.4 }
        let preview = Data([1])
        state.setThumbnail(preview, for: first)
        XCTAssertFalse(state.savePreset(named: "Second"))
        XCTAssertEqual(state.versionSaveError, .copyChangedValues)
        XCTAssertEqual(state.presets.map(\.id), [first])
        XCTAssertEqual(state.activePresetID, first)
        XCTAssertEqual(state.values.opacity, 0.4)
        XCTAssertEqual(state.thumbnail(for: first), preview)
        state.clearActivePreset()
        XCTAssertEqual(state.values.opacity, 0.8)
        state.loadPreset(id: first)
        XCTAssertEqual(state.values.opacity, 0.4)
    }

    func testCustomCopyPreservesNonEncodedReferenceProperties() throws {
        let state = DialPanelState(name: "Runtime", initial: RuntimeInk(), controls: [],
                                  copyValues: { $0.independentCopy() })
        state.updateValues { $0.opacity = 0.4 }
        XCTAssertTrue(state.savePreset(named: "First"))
        let first = try XCTUnwrap(state.activePresetID)
        state.updateValues { $0.opacity = 0.2 }
        XCTAssertTrue(state.savePreset(named: "Second"))
        state.updateValues { $0.opacity = 0.1 }
        state.loadPreset(id: first)
        XCTAssertEqual(state.values.opacity, 0.2)
        state.clearActivePreset()
        XCTAssertEqual(state.values.opacity, 0.4)
    }

    func testCustomCopyPreservesNestedReferenceProperties() {
        struct Model: Codable, Equatable { var ink = RuntimeInk() }
        let state = DialPanelState(name: "Nested", initial: Model(), controls: [],
                                  copyValues: { Model(ink: $0.ink.independentCopy()) })
        state.updateValues { $0.ink.opacity = 0.4 }
        XCTAssertTrue(state.savePreset(named: "First"))
        state.updateValues { $0.ink.opacity = 0.2 }
        state.clearActivePreset()
        XCTAssertEqual(state.values.ink.opacity, 0.4)
    }

    func testValueModelSavePreservesNonEncodedProperties() {
        struct Model: Codable, Equatable {
            var color = "blue"
            var opacity = 0.8
            enum CodingKeys: String, CodingKey { case color }
        }
        let state = DialPanelState(name: "Value", initial: Model(), controls: [])
        state.values.opacity = 0.4
        XCTAssertTrue(state.savePreset(named: "First"))
        state.values.opacity = 0.2
        state.clearActivePreset()
        XCTAssertEqual(state.values.opacity, 0.4)
    }

    func testEncodingFailureIsReportedThroughPanelBoxWithoutCreatingAVersion() {
        enum CopyError: Error { case unavailable }
        final class Model: Codable, Equatable {
            var value = "original"
            func encode(to encoder: Encoder) throws { throw CopyError.unavailable }
            static func == (lhs: Model, rhs: Model) -> Bool { lhs.value == rhs.value }
        }
        let state = DialPanelState(name: "Uncopyable", initial: Model(), controls: [])
        state.setThumbnail(Data([1]), for: nil)
        XCTAssertFalse(state.panelBox.savePreset(named: "First"))
        XCTAssertEqual(state.panelBox.versionSaveError, .copyFailed)
        XCTAssertTrue(state.presets.isEmpty)
        XCTAssertNil(state.activePresetID)
        XCTAssertEqual(state.values.value, "original")
        XCTAssertEqual(state.thumbnail(for: nil), Data([1]))
    }

    func testCustomCopyFailureCanRecoverOnNextSave() {
        enum CopyError: Error { case unavailable }
        var shouldFail = true
        let state = DialPanelState(name: "Runtime", initial: RuntimeInk(), controls: [], copyValues: {
            if shouldFail { throw CopyError.unavailable }
            return $0.independentCopy()
        })
        state.updateValues { $0.opacity = 0.4 }
        XCTAssertFalse(state.savePreset(named: "First"))
        XCTAssertEqual(state.versionSaveError, .copyFailed)
        XCTAssertTrue(state.presets.isEmpty)
        shouldFail = false
        XCTAssertTrue(state.savePreset(named: "First"))
        XCTAssertNil(state.versionSaveError)
        state.updateValues { $0.opacity = 0.2 }
        state.clearActivePreset()
        XCTAssertEqual(state.values.opacity, 0.4)
    }

    func testProgrammaticUpdatesPersistReferenceModels() throws {
        try checkProgrammaticUpdates(initial: InkObject(), color: \.color)
    }

    func testProgrammaticUpdatesPersistNestedReferences() throws {
        try checkProgrammaticUpdates(initial: ReferenceInk(), color: \.ink.color)
    }

    private func checkProgrammaticUpdates<Model: Codable & Equatable>(
        initial: Model, color: WritableKeyPath<Model, String>
    ) throws {
        let key = UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: key))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(key)
        defer {
            defaults.removePersistentDomain(forName: key)
            try? FileManager.default.removeItem(at: directory)
        }
        let storage = DialVersionStorage<Model>(key, defaults: defaults, supportDirectory: directory)
        func makeState() -> DialPanelState<Model> {
            DialPanelState(name: "Ink", initial: initial, controls: [], versionStorage: storage)
        }
        let state = makeState()
        var publishedColors: [String] = []
        let subscription = state.$values.sink { publishedColors.append($0[keyPath: color]) }
        defer { subscription.cancel() }

        state.setThumbnail(Data([1]), for: nil)
        state.updateValues { $0[keyPath: color] = "orange" }
        XCTAssertEqual(publishedColors, ["blue", "orange"])
        XCTAssertNil(state.thumbnail(for: nil))
        XCTAssertNil(storage.thumbnail(for: nil))
        XCTAssertEqual(makeState().values[keyPath: color], "orange")

        let orange = Data([2])
        state.setThumbnail(orange, for: nil)
        state.savePreset(named: "Green")
        let saved = try XCTUnwrap(state.activePresetID)
        state.updateValues { $0[keyPath: color] = "green" }
        XCTAssertEqual(publishedColors, ["blue", "orange", "green"])
        XCTAssertNil(state.thumbnail(for: saved))
        XCTAssertNil(storage.thumbnail(for: saved))
        XCTAssertEqual(state.thumbnail(for: nil), orange)

        let restored = makeState()
        XCTAssertEqual(restored.activePresetID, saved)
        XCTAssertEqual(restored.values[keyPath: color], "green")
        XCTAssertNil(restored.thumbnail(for: saved))
        restored.clearActivePreset()
        XCTAssertEqual(restored.values[keyPath: color], "orange")
        XCTAssertEqual(restored.thumbnail(for: nil), orange)
    }

    private final class OpacityObject: Codable, Equatable {
        var opacity = 0.8
        static func == (lhs: OpacityObject, rhs: OpacityObject) -> Bool { lhs.opacity == rhs.opacity }
    }

    private struct ReferenceOpacity: Codable, Equatable { var appearance = OpacityObject() }

    func testReconfigurationInvalidatesPreviewForNonEncodedReferenceProperty() {
        final class RuntimeModel: Codable, Equatable {
            var name = "Runtime"
            var opacity = 0.8
            enum CodingKeys: String, CodingKey { case name }
            static func == (lhs: RuntimeModel, rhs: RuntimeModel) -> Bool {
                lhs.name == rhs.name && lhs.opacity == rhs.opacity
            }
        }
        let state = DialPanelState(name: "Runtime", initial: RuntimeModel(), controls: [])
        state.setThumbnail(Data([1]), for: nil)
        state.configure(controls: [
            .group("appearance", children: [.slider("opacity", keyPath: \.opacity, range: 0...0.5)])
        ])
        XCTAssertEqual(state.values.opacity, 0.5)
        XCTAssertNil(state.thumbnail(for: nil))
    }

    func testReconfigurationInvalidatesOnlyChangedReferencePreviews() throws {
        try checkNormalization(initial: OpacityObject(), opacity: \.opacity, restore: false)
    }

    func testRestoringWithNewRangeInvalidatesOnlyChangedReferencePreviews() throws {
        try checkNormalization(initial: OpacityObject(), opacity: \.opacity, restore: true)
    }

    func testRestoringWithNewRangeInvalidatesNestedReferencePreviews() throws {
        try checkNormalization(initial: ReferenceOpacity(), opacity: \.appearance.opacity, restore: true)
    }

    private func checkNormalization<Model: Codable & Equatable>(
        initial: Model, opacity: WritableKeyPath<Model, Double>, restore: Bool
    ) throws {
        let key = UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: key))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(key)
        defer {
            defaults.removePersistentDomain(forName: key)
            try? FileManager.default.removeItem(at: directory)
        }
        let storage = DialVersionStorage<Model>(key, defaults: defaults, supportDirectory: directory)
        let originalControls: [DialControl<Model>] = [.slider("opacity", keyPath: opacity, range: 0...1)]
        let reducedControls: [DialControl<Model>] = [.slider("opacity", keyPath: opacity, range: 0...0.5)]
        let state = DialPanelState(name: "Opacity", initial: initial, controls: originalControls, versionStorage: storage)
        state.setThumbnail(Data([1]), for: nil)
        state.savePreset(named: "Low")
        let low = try XCTUnwrap(state.activePresetID)
        guard case let .slider(slider) = state.resolvedControls().first?.kind else {
            return XCTFail("Expected slider control")
        }
        slider.set(0.2)
        let lowPreview = Data([2])
        state.setThumbnail(lowPreview, for: low)
        state.savePreset(named: "High")
        let high = try XCTUnwrap(state.activePresetID)
        slider.set(0.9)
        state.setThumbnail(Data([3]), for: high)

        let normalized: DialPanelState<Model>
        if restore {
            normalized = DialPanelState(name: "Opacity", initial: initial, controls: reducedControls, versionStorage: storage)
        } else {
            state.configure(controls: reducedControls)
            normalized = state
        }
        XCTAssertEqual(normalized.activePresetID, high)
        XCTAssertEqual(normalized.values[keyPath: opacity], 0.5)
        XCTAssertNil(normalized.thumbnail(for: nil))
        XCTAssertNil(normalized.thumbnail(for: high))
        XCTAssertNil(storage.thumbnail(for: nil))
        XCTAssertNil(storage.thumbnail(for: high))
        XCTAssertEqual(normalized.thumbnail(for: low), lowPreview)
        XCTAssertEqual(storage.thumbnail(for: low), lowPreview)
        let archive = try XCTUnwrap(storage.read())
        XCTAssertEqual(archive.base[keyPath: opacity], 0.5)
        XCTAssertEqual(archive.presets.first { $0.id == high }?.values[keyPath: opacity], 0.5)
        XCTAssertEqual(archive.presets.first { $0.id == low }?.values[keyPath: opacity], 0.2)

        normalized.setThumbnail(Data([4]), for: high)
        normalized.configure(controls: reducedControls)
        XCTAssertEqual(normalized.thumbnail(for: high), Data([4]))
        XCTAssertEqual(normalized.thumbnail(for: low), lowPreview)
    }

    func testControlEditsPersistReferenceModelsAndInvalidatePreviews() throws {
        try checkControlEdits(initial: InkObject(), color: \.color)
    }

    func testControlEditsPersistNestedReferencesAndInvalidatePreviews() throws {
        try checkControlEdits(initial: ReferenceInk(), color: \.ink.color)
    }

    func testControlEditsPreserveValueModelBehavior() throws {
        try checkControlEdits(initial: Ink(), color: \.color)
    }

    private func checkControlEdits<Model: Codable & Equatable>(
        initial: Model, color: WritableKeyPath<Model, String>
    ) throws {
        let key = UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: key))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(key)
        defer {
            defaults.removePersistentDomain(forName: key)
            try? FileManager.default.removeItem(at: directory)
        }
        let storage = DialVersionStorage<Model>(key, defaults: defaults, supportDirectory: directory)
        let controls: [DialControl<Model>] = [.text("color", keyPath: color)]
        func makeState() -> DialPanelState<Model> {
            DialPanelState(name: "Ink", initial: initial, controls: controls, versionStorage: storage)
        }
        let state = makeState()
        guard case let .text(text) = state.resolvedControls().first?.kind else {
            return XCTFail("Expected text control")
        }

        state.renameVersion(id: nil, name: "Original")
        state.setThumbnail(Data([1]), for: nil)
        text.set("orange")
        XCTAssertNil(state.thumbnail(for: nil))
        XCTAssertNil(storage.thumbnail(for: nil))
        XCTAssertEqual(makeState().values[keyPath: color], "orange")

        let orange = Data([2])
        state.setThumbnail(orange, for: nil)
        state.savePreset(named: "Green")
        let saved = try XCTUnwrap(state.activePresetID)
        text.set("green")
        XCTAssertNil(state.thumbnail(for: saved))
        XCTAssertNil(storage.thumbnail(for: saved))
        XCTAssertEqual(state.thumbnail(for: nil), orange)

        // Reload before switching versions, which would itself persist the edit.
        let restored = makeState()
        XCTAssertEqual(restored.activePresetID, saved)
        XCTAssertEqual(restored.values[keyPath: color], "green")
        XCTAssertNil(restored.thumbnail(for: saved))
        restored.clearActivePreset()
        XCTAssertEqual(restored.values[keyPath: color], "orange")
        XCTAssertEqual(restored.thumbnail(for: nil), orange)

        let green = Data([3])
        state.setThumbnail(green, for: saved)
        text.set("green")
        XCTAssertEqual(state.thumbnail(for: saved), green)
        XCTAssertEqual(storage.thumbnail(for: saved), green)
    }

    func testSaveCopiesTheOutgoingPreviewAndEditsInvalidateOnlyTheSelectedVersion() throws {
        let state = DialPanelState(name: "Ink", initial: Ink(), controls: [])
        let blue = Data([1])
        let orange = Data([2])
        state.setThumbnail(blue, for: nil)
        state.savePreset(named: "")
        let saved = try XCTUnwrap(state.activePresetID)
        XCTAssertEqual(state.thumbnail(for: saved), blue)
        state.values.color = "orange"
        XCTAssertNil(state.thumbnail(for: saved))
        XCTAssertEqual(state.thumbnail(for: nil), blue)
        state.setThumbnail(orange, for: saved)
        state.clearActivePreset()
        XCTAssertEqual(state.values.color, "blue")
        state.loadPreset(id: saved)
        XCTAssertEqual(state.values.color, "orange")
        XCTAssertEqual(state.thumbnail(for: saved), orange)
        state.deletePreset(id: saved)
        state.setThumbnail(orange, for: saved)
        XCTAssertNil(state.thumbnail(for: saved))
        XCTAssertEqual(state.thumbnail(for: nil), blue)
    }

    func testSavingAReferenceModelDoesNotChangeTheOutgoingVersionOnLaterEdits() throws {
        let state = DialPanelState(name: "Ink", initial: InkObject(), controls: [])
        state.savePreset(named: "Warm")
        let warm = try XCTUnwrap(state.activePresetID)
        state.values.color = "orange"
        state.savePreset(named: "Cool")
        state.values.color = "green"
        state.loadPreset(id: warm)
        XCTAssertEqual(state.values.color, "orange")
        state.clearActivePreset()
        XCTAssertEqual(state.values.color, "blue")
    }

    func testNamesRemainDistinctAfterDeletingAnEarlierVersion() throws {
        let state = DialPanelState(name: "Ink", initial: Ink(), controls: [])
        XCTAssertEqual(state.baseVersionName, "V1")
        state.savePreset(named: "")
        XCTAssertEqual(state.presets.first?.name, "V2")
        let second = try XCTUnwrap(state.activePresetID)
        state.savePreset(named: "")
        state.deletePreset(id: second)
        state.renameVersion(id: nil, name: " V4 ")
        state.renameVersion(id: nil, name: "  ")
        state.savePreset(named: "")
        XCTAssertEqual(state.baseVersionName, "V4")
        XCTAssertEqual(state.presets.map(\.name), ["V3", "V5"])
    }

    func testAutoNamingContinuesPastLegacySavesAndIgnoresCustomLabels() {
        let state = DialPanelState(name: "Ink", initial: Ink(), controls: [])
        state.savePreset(named: "Version 12")
        state.savePreset(named: "V7")
        state.savePreset(named: "Study 99")
        state.savePreset(named: " ")
        XCTAssertEqual(state.presets.map(\.name), ["Version 12", "V7", "Study 99", "V13"])
    }

    func testOptInStorageRestoresValuesSelectionNamesAndPreviews() throws {
        let key = UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: key))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(key)
        defer {
            defaults.removePersistentDomain(forName: key)
            try? FileManager.default.removeItem(at: directory)
        }
        let storage = DialVersionStorage<Ink>(key, defaults: defaults, supportDirectory: directory)
        func makeState() -> DialPanelState<Ink> {
            DialPanelState(name: "Ink", initial: Ink(), controls: [], versionStorage: storage)
        }

        let previous = makeState()
        previous.renameVersion(id: nil, name: "Original")
        previous.setThumbnail(Data([1]), for: nil)
        previous.savePreset(named: "Warm")
        let saved = try XCTUnwrap(previous.activePresetID)
        previous.values.color = "orange"
        previous.setThumbnail(Data([2]), for: saved)
        let restored = makeState()
        XCTAssertEqual(restored.baseVersionName, "Original")
        XCTAssertEqual(restored.activePresetID, saved)
        XCTAssertEqual(restored.presets.first?.name, "Warm")
        XCTAssertEqual(restored.values.color, "orange")
        XCTAssertEqual(restored.thumbnail(for: saved), Data([2]))
        XCTAssertEqual(restored.thumbnail(for: nil), Data([1]))
        restored.deletePreset(id: saved)
        let afterDeletion = makeState()
        XCTAssertNil(afterDeletion.activePresetID)
        XCTAssertEqual(afterDeletion.values.color, "blue")
        XCTAssertNil(storage.thumbnail(for: saved))
    }
}
