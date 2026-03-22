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

    func testDrawerPresentationSnapsBetweenStates() {
        XCTAssertEqual(dialNextDrawerPresentation(from: .hidden, translationHeight: -80), .medium)
        XCTAssertEqual(dialNextDrawerPresentation(from: .medium, translationHeight: -80), .tall)
        XCTAssertEqual(dialNextDrawerPresentation(from: .tall, translationHeight: 80), .medium)
        XCTAssertEqual(dialNextDrawerPresentation(from: .medium, translationHeight: 80), .hidden)
        XCTAssertEqual(dialNextDrawerPresentation(from: .medium, translationHeight: 10), .medium)
    }

    func testResolvedPanelSelectionFallsBackToFirstAvailablePanel() {
        let first = UUID()
        let second = UUID()

        XCTAssertEqual(dialResolvedPanelSelection(current: nil, available: [first, second]), first)
        XCTAssertEqual(dialResolvedPanelSelection(current: second, available: [first, second]), second)
        XCTAssertEqual(dialResolvedPanelSelection(current: UUID(), available: [first, second]), first)
        XCTAssertNil(dialResolvedPanelSelection(current: first, available: []))
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
