import SwiftUI
import XCTest
@testable import DialKit
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class DialKitTests: XCTestCase {
    func testDialRootCompilesInBothModes() {
        _ = DialRoot()
        _ = DialRoot(mode: .inline, storageID: "inline-screen")
        _ = DialRoot(position: .topLeft, defaultOpen: true, mode: .drawer, storageID: "drawer-screen")
    }

    func testReadmeStyleSampleCompiles() {
        struct CardModel: Codable, Equatable {
            var title = "Card"
            var cornerRadius = 24.0
            var isEnabled = true
            var fill = "#F97316"
            var style = "glass"
            var spring: DialSpring = .default
            var transition: DialTransition = .default
        }

        let dial = DialPanelState(
            name: "Card",
            initial: CardModel(),
            controls: [
                .text("title", keyPath: \.title),
                .slider("cornerRadius", keyPath: \.cornerRadius, range: 0.0...48.0, step: 1.0),
                .toggle("isEnabled", keyPath: \.isEnabled),
                .color("fill", keyPath: \.fill),
                .select("style", keyPath: \.style, options: ["glass", "solid"]),
                .group(
                    "motion",
                    children: [
                        .spring("spring", keyPath: \.spring),
                        .transition("transition", keyPath: \.transition),
                        .action("shuffle")
                    ]
                )
            ],
            onAction: { _ in }
        )

        let view = ZStack {
            RoundedRectangle(cornerRadius: dial.values.cornerRadius)
                .fill(Color.orange)
            DialRoot(position: .bottomRight, defaultOpen: false, mode: .drawer, storageID: "card-preview")
        }

        _ = dial
        _ = view
    }

    func testHexColorRoundTripsPreservingAlpha() throws {
        let translucent = try XCTUnwrap(dialColor(from: "#33669980"))
        XCTAssertEqual(dialHexString(from: translucent), "#33669980")

        let opaque = try XCTUnwrap(dialColor(from: "#112233FF"))
        XCTAssertEqual(dialHexString(from: opaque, prefersAlphaOutput: true), "#112233FF")
        XCTAssertTrue(dialHexUsesExplicitAlpha("#112233FF"))
        XCTAssertFalse(dialHexUsesExplicitAlpha("#112233"))
    }

    func testDrawerPresentationSnapsBetweenStates() {
        XCTAssertEqual(dialNextDrawerPresentation(from: .hidden, translationHeight: -80), .medium)
        XCTAssertEqual(dialNextDrawerPresentation(from: .medium, translationHeight: -80), .tall)
        XCTAssertEqual(dialNextDrawerPresentation(from: .tall, translationHeight: 80), .medium)
        XCTAssertEqual(dialNextDrawerPresentation(from: .medium, translationHeight: 80), .hidden)
        XCTAssertEqual(dialNextDrawerPresentation(from: .medium, translationHeight: 10), .medium)
    }

    func testDrawerHelpersMatchPickerAndSpacingRules() {
        XCTAssertFalse(dialDrawerShowsPanelPicker(panelCount: 1))
        XCTAssertTrue(dialDrawerShowsPanelPicker(panelCount: 2))

        XCTAssertEqual(dialDrawerContentInset, 12)
        XCTAssertEqual(dialDrawerHorizontalInset, 8)
        XCTAssertEqual(dialDrawerToolbarBottomPadding, 6)
        XCTAssertEqual(dialDrawerChromeHeight(panelCount: 1), 69)
        XCTAssertEqual(dialDrawerChromeHeight(panelCount: 2), 109)
    }

    func testResolvedDrawerWidthUsesSingleOuterInsetPerSide() {
        XCTAssertEqual(dialResolvedDrawerWidth(containerWidth: 390), 374)
        XCTAssertEqual(dialResolvedDrawerWidth(containerWidth: 320), 304)
        XCTAssertEqual(dialResolvedDrawerWidth(containerWidth: 12), 0)
    }

    func testKeyboardInsetAndAvailableDrawerHeightClampAtZero() {
        XCTAssertEqual(dialResolvedKeyboardAvoidanceInset(keyboardOverlap: 180), 180)
        XCTAssertEqual(dialResolvedKeyboardAvoidanceInset(keyboardOverlap: -20), 0)
        XCTAssertEqual(
            dialResolvedDrawerAvailableHeight(containerHeight: 640, keyboardOverlap: 216),
            424
        )
        XCTAssertEqual(
            dialResolvedDrawerAvailableHeight(containerHeight: 120, keyboardOverlap: 180),
            0
        )
    }

    func testResolvedDrawerMaximumHeightsUseKeyboardAdjustedAvailableHeight() {
        let heights = dialResolvedDrawerMaximumHeights(containerHeight: 640, keyboardOverlap: 216)

        XCTAssertEqual(heights.medium, 245.92, accuracy: 0.001)
        XCTAssertEqual(heights.tall, 381.6, accuracy: 0.001)
    }

    func testFocusedTextEntryPromotesOnlyMediumDrawer() {
        XCTAssertTrue(
            dialShouldPromoteDrawerForFocusedTextEntry(
                presentation: .medium,
                focusedTextEntryID: "title"
            )
        )
        XCTAssertFalse(
            dialShouldPromoteDrawerForFocusedTextEntry(
                presentation: .tall,
                focusedTextEntryID: "title"
            )
        )
        XCTAssertFalse(
            dialShouldPromoteDrawerForFocusedTextEntry(
                presentation: .medium,
                focusedTextEntryID: nil
            )
        )
    }

    func testActivePresetNameFallsBackToVersionOneWhenNoPresetIsSelected() {
        let first = DialPresetSummary(id: UUID(), name: "Version 2")

        XCTAssertEqual(
            dialActivePresetName(activePresetID: nil, presets: [first]),
            "Version 1"
        )
    }

    func testActivePresetNameUsesSelectedPresetName() {
        let first = DialPresetSummary(id: UUID(), name: "Version 2")
        let second = DialPresetSummary(id: UUID(), name: "Version 3")

        XCTAssertEqual(
            dialActivePresetName(activePresetID: second.id, presets: [first, second]),
            "Version 3"
        )
    }

    func testPresetSelectionActionClearsWhenSelectingBaseState() {
        XCTAssertEqual(
            dialPresetSelectionAction(for: nil),
            .clear
        )
    }

    func testPresetSelectionActionLoadsSelectedPresetID() {
        let presetID = UUID()

        XCTAssertEqual(
            dialPresetSelectionAction(for: presetID),
            .load(presetID)
        )
    }

    func testDrawerSectionDividerVisibilitySkipsFirstSection() {
        let controls = [groupControl(path: "layout")]

        XCTAssertEqual(
            dialSectionDividerVisibility(at: 0, in: controls),
            DialSectionDividerVisibility(showsTopDivider: false, showsBottomDivider: false)
        )
    }

    func testDrawerSectionDividerVisibilityAddsSingleDividerAboveLaterSection() {
        let controls = [
            groupControl(path: "layout"),
            springControl(path: "motion.spring")
        ]

        XCTAssertEqual(
            dialSectionDividerVisibility(at: 1, in: controls),
            DialSectionDividerVisibility(showsTopDivider: true, showsBottomDivider: false)
        )
    }

    func testDrawerSectionDividerVisibilityIgnoresNonSectionRowsUntilLaterSection() {
        let controls = [
            sliderControl(path: "columns"),
            groupControl(path: "layout"),
            textControl(path: "title"),
            transitionControl(path: "motion.transition")
        ]

        XCTAssertEqual(
            dialSectionDividerVisibility(at: 1, in: controls),
            DialSectionDividerVisibility(showsTopDivider: false, showsBottomDivider: false)
        )
        XCTAssertEqual(
            dialSectionDividerVisibility(at: 3, in: controls),
            DialSectionDividerVisibility(showsTopDivider: true, showsBottomDivider: false)
        )
    }

    func testDrawerSectionDividerVisibilityNeverRequestsTrailingDivider() {
        let controls = [
            groupControl(path: "layout"),
            transitionControl(path: "motion.transition")
        ]

        XCTAssertFalse(dialSectionDividerVisibility(at: 1, in: controls).showsBottomDivider)
    }

    func testAccordionIDsCollectAccordionCapableControlsRecursively() {
        let nestedSpring = DialResolvedControl(
            path: "motion.spring",
            label: "Spring",
            kind: .spring(
                DialResolvedSpring(
                    get: { .default },
                    set: { _ in }
                )
            )
        )
        let nestedTransition = DialResolvedControl(
            path: "motion.timing.transition",
            label: "Transition",
            kind: .transition(
                DialResolvedTransition(
                    get: { .default },
                    set: { _ in }
                )
            )
        )
        let nestedGroup = DialResolvedControl(
            path: "motion.timing",
            label: "Timing",
            kind: .group(
                DialResolvedGroup(
                    collapsed: true,
                    children: [nestedTransition]
                )
            )
        )
        let rootGroup = DialResolvedControl(
            path: "motion",
            label: "Motion",
            kind: .group(
                DialResolvedGroup(
                    collapsed: false,
                    children: [
                        nestedSpring,
                        nestedGroup,
                        DialResolvedControl(
                            path: "motion.enabled",
                            label: "Enabled",
                            kind: .toggle(
                                DialResolvedToggle(
                                    get: { true },
                                    set: { _ in }
                                )
                            )
                        )
                    ]
                )
            )
        )
        let title = DialResolvedControl(
            path: "title",
            label: "Title",
            kind: .text(
                DialResolvedText(
                    placeholder: "Title",
                    get: { "DialKit" },
                    set: { _ in }
                )
            )
        )

        XCTAssertEqual(
            dialAccordionIDs(in: [rootGroup, title]),
            Set([
                "motion|group|false",
                "motion.spring",
                "motion.timing|group|true",
                "motion.timing.transition"
            ])
        )
    }

    func testResolvedDrawerHeightUsesIntrinsicHeightForShortContent() {
        let medium = dialResolvedDrawerHeight(
            presentation: .medium,
            intrinsicContentHeight: 220,
            mediumMaxHeight: 360,
            tallMaxHeight: 620
        )
        let tall = dialResolvedDrawerHeight(
            presentation: .tall,
            intrinsicContentHeight: 220,
            mediumMaxHeight: 360,
            tallMaxHeight: 620
        )

        XCTAssertEqual(medium, 220)
        XCTAssertEqual(tall, 220)
    }

    func testResolvedDrawerHeightClampsMediumOverflow() {
        XCTAssertEqual(
            dialResolvedDrawerHeight(
                presentation: .medium,
                intrinsicContentHeight: 520,
                mediumMaxHeight: 360,
                tallMaxHeight: 620
            ),
            360
        )
    }

    func testResolvedDrawerHeightClampsTallOverflow() {
        XCTAssertEqual(
            dialResolvedDrawerHeight(
                presentation: .tall,
                intrinsicContentHeight: 720,
                mediumMaxHeight: 360,
                tallMaxHeight: 620
            ),
            620
        )
    }

    func testDrawerControlsHeightCapSubtractsChromeOnce() {
        XCTAssertEqual(
            dialDrawerControlsHeightCap(
                presentation: .medium,
                panelCount: 1,
                mediumMaxHeight: 360,
                tallMaxHeight: 620
            ),
            291
        )
        XCTAssertEqual(
            dialDrawerControlsHeightCap(
                presentation: .tall,
                panelCount: 2,
                mediumMaxHeight: 360,
                tallMaxHeight: 620
            ),
            511
        )
    }

    func testDrawerControlsBelowCapDoNotScroll() {
        XCTAssertFalse(
            dialDrawerControlsShouldScroll(
                intrinsicContentHeight: 56,
                maxHeight: 291
            )
        )
    }

    func testDrawerControlsAboveCapRequestScrolling() {
        XCTAssertTrue(
            dialDrawerControlsShouldScroll(
                intrinsicContentHeight: 320,
                maxHeight: 291
            )
        )
    }

    func testDrawerControlsRequestScrollingWhileTextEntryIsFocused() {
        XCTAssertTrue(
            dialDrawerControlsShouldScroll(
                intrinsicContentHeight: 56,
                maxHeight: nil,
                focusedTextEntryID: "title"
            )
        )
        XCTAssertTrue(
            dialDrawerControlsShouldScroll(
                intrinsicContentHeight: 56,
                maxHeight: 291,
                keyboardOverlap: 240
            )
        )
    }

    func testResolvedControlsBottomInsetAddsKeyboardInsetWithoutGoingNegative() {
        XCTAssertEqual(
            dialResolvedControlsBottomInset(baseInset: 12, keyboardOverlap: 216),
            228
        )
        XCTAssertEqual(
            dialResolvedControlsBottomInset(baseInset: 12, keyboardOverlap: -40),
            12
        )
    }

    func testResolvedDrawerControlsViewportHeightUsesIntrinsicHeightForShortContent() {
        XCTAssertEqual(
            dialResolvedDrawerControlsViewportHeight(
                intrinsicContentHeight: 56,
                maxHeight: 291
            ),
            56
        )
    }

    func testResolvedDrawerControlsViewportHeightClampsOverflowToCap() {
        XCTAssertEqual(
            dialResolvedDrawerControlsViewportHeight(
                intrinsicContentHeight: 320,
                maxHeight: 291
            ),
            291
        )
    }

    func testSliderSnappingReturnsSameStepWithinBoundary() {
        XCTAssertEqual(dialSnappedSliderValue(0.11, range: 0.0...1.0, step: 0.1), 0.1, accuracy: 0.0001)
        XCTAssertEqual(dialSnappedSliderValue(0.14, range: 0.0...1.0, step: 0.1), 0.1, accuracy: 0.0001)
    }

    func testSliderSnappingChangesAcrossBoundary() {
        XCTAssertEqual(dialSnappedSliderValue(0.16, range: 0.0...1.0, step: 0.1), 0.2, accuracy: 0.0001)
        XCTAssertEqual(dialSnappedSliderValue(0.26, range: 0.0...1.0, step: 0.1), 0.3, accuracy: 0.0001)
    }

    func testSliderSnappingClampsToRange() {
        XCTAssertEqual(dialSnappedSliderValue(-0.5, range: 0.0...1.0, step: 0.1), 0.0, accuracy: 0.0001)
        XCTAssertEqual(dialSnappedSliderValue(1.6, range: 0.0...1.0, step: 0.1), 1.0, accuracy: 0.0001)
    }

    func testSliderSnappingAnchorsStepsToRangeLowerBound() {
        XCTAssertEqual(dialSnappedSliderValue(1.0, range: 1.0...9.0, step: 2.0), 1.0, accuracy: 0.0001)
        XCTAssertEqual(dialSnappedSliderValue(2.9, range: 1.0...9.0, step: 2.0), 3.0, accuracy: 0.0001)
        XCTAssertEqual(dialSnappedSliderValue(5.1, range: 1.0...9.0, step: 2.0), 5.0, accuracy: 0.0001)
        XCTAssertEqual(dialSnappedSliderValue(8.6, range: 1.0...9.0, step: 2.0), 9.0, accuracy: 0.0001)
    }

    func testSliderHapticHelperOnlyFiresOnStepChange() {
        XCTAssertFalse(dialShouldEmitSliderHaptic(previousValue: nil, nextValue: 0.1))
        XCTAssertFalse(dialShouldEmitSliderHaptic(previousValue: 0.1, nextValue: 0.1))
        XCTAssertTrue(dialShouldEmitSliderHaptic(previousValue: 0.1, nextValue: 0.2))
    }

    func testSliderGestureDispositionWaitsForMeaningfulMovement() {
        XCTAssertEqual(
            dialResolveSliderGestureDisposition(translation: CGSize(width: 6, height: 5)),
            .undecided
        )
    }

    func testSliderGestureDispositionLocksForHorizontalMovement() {
        XCTAssertEqual(
            dialResolveSliderGestureDisposition(translation: CGSize(width: 12, height: 3)),
            .slider
        )
    }

    func testSliderGestureDispositionYieldsToScrollForVerticalMovement() {
        XCTAssertEqual(
            dialResolveSliderGestureDisposition(translation: CGSize(width: 3, height: 12)),
            .scroll
        )
    }

    func testSliderGestureDispositionRequiresHorizontalDominanceForDiagonalDrag() {
        XCTAssertEqual(
            dialResolveSliderGestureDisposition(translation: CGSize(width: 10, height: 9)),
            .scroll
        )
        XCTAssertEqual(
            dialResolveSliderGestureDisposition(translation: CGSize(width: 12, height: 9)),
            .slider
        )
    }

    func testResolvedPanelSelectionFallsBackToFirstAvailablePanel() {
        let first = UUID()
        let second = UUID()

        XCTAssertEqual(dialResolvedPanelSelection(current: nil, available: [first, second]), first)
        XCTAssertEqual(dialResolvedPanelSelection(current: second, available: [first, second]), second)
        XCTAssertEqual(dialResolvedPanelSelection(current: UUID(), available: [first, second]), first)
        XCTAssertNil(dialResolvedPanelSelection(current: first, available: []))
    }

    private func sliderControl(path: String) -> DialResolvedControl {
        DialResolvedControl(
            path: path,
            label: path,
            kind: .slider(
                DialResolvedSlider(
                    range: 0...1,
                    step: 0.1,
                    unit: nil,
                    get: { 0 },
                    set: { _ in }
                )
            )
        )
    }

    private func textControl(path: String) -> DialResolvedControl {
        DialResolvedControl(
            path: path,
            label: path,
            kind: .text(
                DialResolvedText(
                    placeholder: nil,
                    get: { "" },
                    set: { _ in }
                )
            )
        )
    }

    private func springControl(path: String) -> DialResolvedControl {
        DialResolvedControl(
            path: path,
            label: path,
            kind: .spring(
                DialResolvedSpring(
                    get: { .default },
                    set: { _ in }
                )
            )
        )
    }

    private func transitionControl(path: String) -> DialResolvedControl {
        DialResolvedControl(
            path: path,
            label: path,
            kind: .transition(
                DialResolvedTransition(
                    get: { .default },
                    set: { _ in }
                )
            )
        )
    }

    private func groupControl(path: String) -> DialResolvedControl {
        DialResolvedControl(
            path: path,
            label: path,
            kind: .group(
                DialResolvedGroup(
                    collapsed: false,
                    children: []
                )
            )
        )
    }

    #if canImport(UIKit)
    func testFABStoragePersistsByStorageID() {
        let suiteName = "DialKitTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let firstPoint = CGPoint(x: 72, y: 180)
        let secondPoint = CGPoint(x: 240, y: 540)

        DialFABStorage.save(firstPoint, storageID: "screen-a", userDefaults: defaults)
        DialFABStorage.save(secondPoint, storageID: "screen-b", userDefaults: defaults)

        XCTAssertEqual(DialFABStorage.load(storageID: "screen-a", userDefaults: defaults), firstPoint)
        XCTAssertEqual(DialFABStorage.load(storageID: "screen-b", userDefaults: defaults), secondPoint)

        DialFABStorage.save(nil, storageID: "screen-a", userDefaults: defaults)
        XCTAssertNil(DialFABStorage.load(storageID: "screen-a", userDefaults: defaults))
        XCTAssertEqual(DialFABStorage.load(storageID: "screen-b", userDefaults: defaults), secondPoint)
    }

    func testClampedFABCenterRespectsInsetsAndBounds() {
        let clamped = dialClampedFABCenter(
            CGPoint(x: -100, y: 1000),
            in: CGSize(width: 320, height: 640),
            safeAreaInsets: UIEdgeInsets(top: 44, left: 0, bottom: 34, right: 0),
            diameter: 56,
            horizontalMargin: 8,
            topMargin: 8,
            bottomMargin: 2
        )

        XCTAssertEqual(clamped.x, 36, accuracy: 0.001)
        XCTAssertEqual(clamped.y, 576, accuracy: 0.001)
    }
    #endif
}
