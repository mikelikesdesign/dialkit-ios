import SwiftUI

/// Shared native selection indicator for version labels.
struct DialVersionCheckmark: View {
    @ScaledMetric(relativeTo: .caption) private var size = 14.0

    var body: some View {
        Image(systemName: "checkmark")
            .font(.system(size: size, weight: .semibold))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
