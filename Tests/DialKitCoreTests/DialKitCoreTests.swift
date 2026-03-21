import XCTest
@testable import DialKitCore

@MainActor
final class DialKitCoreTests: XCTestCase {
    struct DemoModel: Codable, Equatable {
        var opacity: Double = 0.5
        var enabled = true
        var title = "Hello"
        var accent = "#FF0000"
        var variant = "primary"
        var spring: DialSpring = .default
        var transition: DialTransition = .default
    }

    override func setUp() {
        super.setUp()
        DialStore.shared.resetForTesting()
    }

    func testPanelRegisterAndUnregisterTracksStore() {
        weak var weakState: DialPanelState<DemoModel>?

        do {
            var state: DialPanelState<DemoModel>? = makeState()
            weakState = state

            XCTAssertEqual(DialStore.shared.panels.map(\.id), [state?.id].compactMap { $0 })

            state = nil
        }

        XCTAssertNil(weakState)
        XCTAssertTrue(DialStore.shared.panels.isEmpty)
    }

    func testResolvedControlMetadataIncludesNestedChildren() {
        let state = makeState()
        let resolved = state.resolvedControls()

        XCTAssertEqual(resolved.map(\.path), ["opacity", "enabled", "title", "accent", "variant", "motion"])

        guard case let .group(group) = resolved.last?.kind else {
            XCTFail("Expected motion group")
            return
        }

        XCTAssertEqual(group.children.map(\.path), ["motion.spring", "motion.transition", "motion.reset"])
    }

    func testConfigurePreservesCompatibleValuesAndClampsInvalidOnes() {
        let state = makeState()
        state.values.opacity = 0.86
        state.values.enabled = false
        state.values.title = "Updated"
        state.values.accent = "oops"
        state.values.variant = "secondary"

        state.configure(
            initial: DemoModel(opacity: 0.2, enabled: true, title: "Base", accent: "#00FF00", variant: "primary"),
            controls: [
                .slider("opacity", keyPath: \.opacity, range: 0.0...0.5, step: 0.1),
                .toggle("enabled", keyPath: \.enabled),
                .text("title", keyPath: \.title),
                .color("accent", keyPath: \.accent),
                .select("variant", keyPath: \.variant, options: ["primary"]),
                .group(
                    "motion",
                    children: [
                        .spring("spring", keyPath: \.spring),
                        .transition("transition", keyPath: \.transition),
                        .action("reset")
                    ]
                )
            ]
        )

        XCTAssertEqual(state.values.opacity, 0.5, accuracy: 0.0001)
        XCTAssertEqual(state.values.enabled, false)
        XCTAssertEqual(state.values.title, "Updated")
        XCTAssertEqual(state.values.accent, "#00FF00")
        XCTAssertEqual(state.values.variant, "primary")
    }

    func testPresetLifecycleAndBaseRestore() throws {
        let state = makeState()
        state.values.opacity = 0.8

        state.savePreset(named: "Hero")
        let presetID = try XCTUnwrap(state.activePresetID)

        state.values.opacity = 0.3
        XCTAssertEqual(try XCTUnwrap(state.presets.first?.values.opacity), 0.3, accuracy: 0.0001)

        state.clearActivePreset()
        XCTAssertNil(state.activePresetID)
        XCTAssertEqual(state.values.opacity, 0.8, accuracy: 0.0001)

        state.loadPreset(id: presetID)
        XCTAssertEqual(state.values.opacity, 0.3, accuracy: 0.0001)

        state.deletePreset(id: presetID)
        XCTAssertTrue(state.presets.isEmpty)
        XCTAssertNil(state.activePresetID)
    }

    func testTransitionModeSwitchingProducesExpectedShapes() {
        let easing = DialTransition.spring(.time(duration: 0.45, bounce: 0.3)).switching(to: .easing)
        guard case let .easing(duration, bezier) = easing else {
            return XCTFail("Expected easing transition")
        }
        XCTAssertEqual(duration, 0.45, accuracy: 0.0001)
        XCTAssertEqual(bezier, .standard)

        let advanced = easing.switching(to: .advanced)
        guard case let .spring(spring) = advanced,
              case let .physics(stiffness, damping, mass) = spring else {
            return XCTFail("Expected advanced spring transition")
        }
        XCTAssertEqual(stiffness, 200, accuracy: 0.0001)
        XCTAssertEqual(damping, 25, accuracy: 0.0001)
        XCTAssertEqual(mass, 1, accuracy: 0.0001)
    }

    func testActionCallbacksUseStableNestedPaths() {
        var triggered: [String] = []
        let state = DialPanelState(
            name: "Preview",
            initial: DemoModel(),
            controls: DemoModel.controls,
            onAction: { triggered.append($0) }
        )

        let resolved = state.resolvedControls()
        guard case let .group(group) = resolved.last?.kind,
              case let .action(action) = group.children.last?.kind else {
            return XCTFail("Expected nested action")
        }

        action.trigger()
        XCTAssertEqual(triggered, ["motion.reset"])
    }

    func testCopyInstructionIncludesPromptAndJson() {
        let state = makeState()
        let text = state.copyInstructionText()

        XCTAssertTrue(text.contains("Update the DialKit configuration for \"Preview\""))
        XCTAssertTrue(text.contains("```json"))
        XCTAssertTrue(text.contains("\"title\""))
        XCTAssertTrue(text.contains("Apply these values as the new defaults"))
    }

    private func makeState() -> DialPanelState<DemoModel> {
        DialPanelState(name: "Preview", initial: DemoModel(), controls: DemoModel.controls)
    }
}

private extension DialKitCoreTests.DemoModel {
    static var controls: [DialControl<Self>] {
        [
            .slider("opacity", keyPath: \.opacity, range: 0.0...1.0, step: 0.1),
            .toggle("enabled", keyPath: \.enabled),
            .text("title", keyPath: \.title, placeholder: "Title"),
            .color("accent", keyPath: \.accent),
            .select("variant", keyPath: \.variant, options: ["primary", "secondary"]),
            .group(
                "motion",
                children: [
                    .spring("spring", keyPath: \.spring),
                    .transition("transition", keyPath: \.transition),
                    .action("reset")
                ]
            )
        ]
    }
}
