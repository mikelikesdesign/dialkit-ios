import SwiftUI
import XCTest
@testable import DialKit

@MainActor
final class DialKitTests: XCTestCase {
    func testDialRootCompilesInBothModes() {
        _ = DialRoot()
        _ = DialRoot(position: .bottomLeft, defaultOpen: false, mode: .inline)
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
            DialRoot(position: .topRight, defaultOpen: true, mode: .popover)
        }

        _ = dial
        _ = view
    }
}
