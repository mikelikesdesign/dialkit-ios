# DialKit

DialKit is a SwiftUI control panel package for tuning view state at runtime on iOS 17 and later.

> Work in progress: this package is still being actively developed and the API may change.

## Credit

This package is a forked Swift package adaptation of Josh Puckett's open source DialKit project.

- Creator of the upstream project: [Josh Puckett](https://github.com/joshpuckett)
- Upstream repository: [joshpuckett/dialkit](https://github.com/joshpuckett/dialkit)

## Requirements

- iOS 17 and later
- SwiftUI
- A model type that conforms to `Codable` and `Equatable`

## Installation

Add this repository as a Swift Package dependency in Xcode, then import `DialKit` in your app.

```swift
import DialKit
```

## Core Concepts

DialKit has three main pieces:

- `DialPanelState<Model>`: owns the editable values for one panel
- `DialControl<Model>`: describes the controls that should be shown for that model
- `DialRoot`: renders every registered panel from the shared global store

The typical flow is:

1. Define a `Model` that contains the values you want to tune.
2. Create a `DialPanelState<Model>` with an initial value and a list of controls.
3. Bind your UI directly to `dial.values`.
4. Add a single `DialRoot` near the top of your screen hierarchy.

## Quick Start

```swift
import DialKit
import SwiftUI

struct CardModel: Codable, Equatable {
    var title = "Card"
    var cornerRadius = 24.0
    var isEnabled = true
    var fill = "#F97316"
    var style = "glass"
    var spring: DialSpring = .default
    var transition: DialTransition = .default
}

struct CardPreview: View {
    @StateObject private var dial = DialPanelState(
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
        onAction: { path in
            print("Dial action:", path)
        }
    )

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: dial.values.cornerRadius)
                .fill(dial.values.isEnabled ? .orange : .gray)
                .overlay {
                    Text(dial.values.title)
                        .foregroundStyle(.white)
                }
                .padding(40)

            DialRoot(
                position: .bottomRight,
                defaultOpen: false,
                mode: .drawer,
                storageID: "card-preview"
            )
        }
    }
}
```

A few important details:

- Keep `DialPanelState` alive for as long as you want the panel to exist. In SwiftUI that usually means `@StateObject`.
- `dial.values` is the source of truth for the tuned values.
- You only need one `DialRoot` to render every active panel.
- In drawer mode, `DialRoot` shows a draggable FAB first and opens a mobile bottom drawer when tapped.

## Public API Overview

### `DialRoot`

```swift
DialRoot(
    position: .bottomRight,
    defaultOpen: false,
    mode: .drawer,
    storageID: "default"
)
```

Supported positions:

- `.topRight`
- `.topLeft`
- `.bottomRight`
- `.bottomLeft`

In drawer mode, `position` is the initial FAB anchor, not a panel alignment.

Supported modes:

- `.drawer`: draggable FAB + mobile bottom drawer
- `.inline`: always-expanded panel rendered in place

Drawer behavior:

- `defaultOpen: false` starts closed with only the FAB visible
- `defaultOpen: true` starts with the drawer open at the medium height
- `storageID` namespaces the persisted FAB position so different screens do not collide

`drawer` mode is currently iPhone-first. A dedicated iPad presentation is deferred for now.

### `DialPanelState<Model>`

```swift
DialPanelState(
    name: "Card",
    initial: CardModel(),
    controls: [...],
    onAction: { path in ... }
)
```

Public behavior:

- `values`: the current tuned model
- `presets`: saved presets for that panel
- `activePresetID`: currently loaded preset, if any
- `controls`: the current control definitions
- `configure(name:initial:controls:)`: update the control config at runtime
- `savePreset(named:)`
- `loadPreset(id:)`
- `clearActivePreset()`
- `deletePreset(id:)`
- `copyInstructionText()`

## Defining Controls

DialKit uses writable key paths into your model. Each control gets a path string and a key path.

```swift
[
    .slider("opacity", keyPath: \.opacity, range: 0.0...1.0, step: 0.05),
    .toggle("enabled", keyPath: \.enabled),
    .text("title", keyPath: \.title, placeholder: "Title"),
    .color("fill", keyPath: \.fill),
    .select("style", keyPath: \.style, options: ["glass", "solid"]),
    .spring("spring", keyPath: \.spring),
    .transition("transition", keyPath: \.transition),
    .group("motion", collapsed: false, children: [...]),
    .action("shuffle")
]
```

Supported controls:

- `slider`: numeric values backed by `Double`, `Float`, `CGFloat`, or `Int`
- `toggle`: `Bool`
- `text`: `String`
- `color`: `String` hex color values
- `select`: `String` with either `[String]` or `[DialOption]`
- `spring`: `DialSpring`
- `transition`: `DialTransition`
- `group`: nested folders of controls
- `action`: callback-only button routed through `onAction`

Paths are also used to generate stable action identifiers. A nested action inside `group("motion")` with `action("shuffle")` is delivered as `motion.shuffle`.

## Working With Multiple Panels

Multiple panel states can exist at the same time. They automatically register with the shared `DialStore`.

```swift
struct MultiPreview: View {
    @StateObject private var cardDial = DialPanelState(
        name: "Card",
        initial: CardModel(),
        controls: CardModel.controls
    )

    @StateObject private var shadowDial = DialPanelState(
        name: "Shadow",
        initial: ShadowModel(),
        controls: ShadowModel.controls
    )

    var body: some View {
        ZStack {
            PreviewSurface(card: cardDial.values, shadow: shadowDial.values)
            DialRoot(storageID: "multi-preview")
        }
    }
}
```

Drawer mode uses one shared drawer. If multiple panels are active, DialKit shows a picker in the drawer header and renders the selected panel. Inline mode renders all active panels in place.

## Presets, Base State, and Copy

Each panel supports in-memory presets.

- When no preset is selected, edits update the panel's base values.
- When a preset is active, edits automatically update that preset.
- `clearActivePreset()` restores the current base values.
- `copyInstructionText()` returns a prompt block plus JSON, not raw JSON alone.

The built-in UI already exposes preset save/load/delete and copy actions.

## Actions

Action controls are useful when you want the panel to trigger app logic that is not a direct key-path write.

```swift
let dial = DialPanelState(
    name: "Card",
    initial: CardModel(),
    controls: [
        .group(
            "actions",
            children: [
                .action("shuffle"),
                .action("resetLayout")
            ]
        )
    ],
    onAction: { path in
        switch path {
        case "actions.shuffle":
            print("shuffle")
        case "actions.resetLayout":
            print("reset")
        default:
            break
        }
    }
)
```

## Springs and Transitions

DialKit includes two animation-oriented value types.

### `DialSpring`

```swift
.time(duration: 0.35, bounce: 0.24)
.physics(stiffness: 200, damping: 25, mass: 1)
```

The spring control can switch between time-based and physics-based editing.

### `DialTransition`

```swift
.easing(duration: 0.3, bezier: .standard)
.spring(.default)
```

The transition control supports:

- easing curves via `DialBezier`
- time-based spring mode
- physics spring mode

## Colors

Color controls are stored as strings for parity with the upstream DialKit model.

Supported formats:

- `#RGB`
- `#RRGGBB`
- `#RRGGBBAA`

Example:

```swift
var fill = "#F97316"
```

DialKit converts these values to SwiftUI colors internally for the built-in control UI.

## Runtime Reconfiguration

You can swap the control schema at runtime by calling `configure(name:initial:controls:)` on an existing panel state.

```swift
dial.configure(
    name: "Card",
    initial: CardModel(),
    controls: CardModel.advancedControls
)
```

When you reconfigure a panel:

- compatible current values are preserved
- invalid values are clamped or reset to fallback values
- existing presets are normalized to the new control schema

## Tips

- Add `DialRoot` close to the top of your screen hierarchy so the FAB and drawer can overlay your content.
- Use a unique `storageID` per screen if you want each screen to remember its own FAB position.
- Use `inline` mode for settings screens, inspectors, or debug panels that should always stay visible.
- Keep your model small and focused. DialKit works best when each panel represents a coherent group of values.
- Prefer stable path names because they become labels, nested control identifiers, and action paths.

## Current Limitations

- The package is still a work in progress.
- Presets are in-memory only. Persistence is up to the host app.
- Drawer mode is currently iPhone-first. A dedicated iPad presentation has not been added yet.
- The API is intentionally package-first right now; an example app is not bundled yet.
- Color values are stored as hex strings rather than `Color` values.

## Features

- Config-driven controls keyed by writable key paths into your model
- Shared global store for multiple panels
- Draggable FAB with persisted position per `storageID`
- Mobile drawer presentation plus inline presentation
- Presets with base-state restore and active-preset autosave
- Nested groups, spring controls, transition controls, actions, text, toggle, color, select, and slider controls
