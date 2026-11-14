import SwiftUI
import DialKitCore
#if canImport(UIKit)
import UIKit

private typealias ArtworkCapture = @MainActor () -> UIImage?

private struct CustomCaptureKey: EnvironmentKey {
    static let defaultValue: [UUID: ArtworkCapture] = [:]
}

private extension EnvironmentValues {
    var dialArtworkCaptures: [UUID: ArtworkCapture] {
        get { self[CustomCaptureKey.self] }
        set { self[CustomCaptureKey.self] = newValue }
    }
}

public extension View {
    /// Frame a specific SwiftUI view for this panel's thumbnails. Give it an intrinsic
    /// size or an explicit frame. Other panels keep their automatic window captures.
    func dialVersionPreview<Model, Artwork: View>(
        for panel: DialPanelState<Model>, @ViewBuilder artwork: @escaping (Model) -> Artwork
    ) -> some View {
        modifier(ArtworkSource(panel: panel, artwork: artwork))
    }
}

private struct ArtworkSource<Model: Codable & Equatable, Artwork: View>: ViewModifier {
    let panel: DialPanelState<Model>
    let artwork: (Model) -> Artwork
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize

    func body(content: Content) -> some View {
        content.transformEnvironment(\.dialArtworkCaptures) { sources in
            sources[panel.id] = {
                let view = artwork(panel.values)
                    .environment(\.colorScheme, scheme)
                    .environment(\.dynamicTypeSize, typeSize)
                return ImageRenderer(content: view).uiImage
            }
        }
    }
}

@MainActor
private final class CaptureSource: ObservableObject {
    weak var anchor: UIView?

    func capture(custom: ArtworkCapture?) -> Data? {
        if let custom {
            guard let image = custom() else { return nil }
            return thumbnail(size: image.size) { _ in
                image.draw(in: CGRect(origin: .zero, size: image.size))
                return true
            }
        }
        guard let anchor, let window = anchor.window else { return nil }
        let safe = window.bounds.inset(by: window.safeAreaInsets)
        let panel = anchor.convert(anchor.bounds, to: window)
        // Draw just the exposed host content, excluding the editor in its own window.
        let above = safe.intersection(CGRect(x: safe.minX, y: safe.minY, width: safe.width,
                                             height: max(0, panel.minY - safe.minY)))
        let below = safe.intersection(CGRect(x: safe.minX, y: panel.maxY, width: safe.width,
                                             height: max(0, safe.maxY - panel.maxY)))
        let region = above.height >= below.height ? above : below
        guard region.width >= 44, region.height >= 44 else { return nil }
        return thumbnail(size: region.size) { context in
            context.translateBy(x: -region.minX, y: -region.minY)
            return window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
    }

    private func thumbnail(size: CGSize, draw: (CGContext) -> Bool) -> Data? {
        guard size.width > 0, size.height > 0, size.width.isFinite, size.height.isFinite else { return nil }
        let scale = min(1, 600 / max(size.width, size.height))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let outputSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: outputSize, format: format)
        var success = false
        let data = renderer.jpegData(withCompressionQuality: 0.78) { context in
            UIColor.systemBackground.setFill()
            context.fill(CGRect(origin: .zero, size: outputSize))
            context.cgContext.scaleBy(x: scale, y: scale)
            success = draw(context.cgContext)
        }
        return success ? data : nil
    }
}

private struct CaptureAnchor: UIViewRepresentable {
    let source: CaptureSource
    func makeUIView(context: Context) -> UIView {
        let anchor = UIView()
        anchor.isUserInteractionEnabled = false
        source.anchor = anchor
        return anchor
    }
    func updateUIView(_ view: UIView, context: Context) { source.anchor = view }
}

private struct CaptureBoundary: ViewModifier {
    @StateObject private var source = CaptureSource()
    @Environment(\.dialArtworkCaptures) private var sources

    func body(content: Content) -> some View {
        content
            .background { CaptureAnchor(source: source).allowsHitTesting(false).accessibilityHidden(true) }
            .environment(\.dialCaptureVersion, { source.capture(custom: sources[$0]) })
    }
}
#endif

private struct CaptureKey: EnvironmentKey {
    static let defaultValue: @MainActor (UUID) -> Data? = { _ in nil }
}

extension EnvironmentValues {
    var dialCaptureVersion: @MainActor (UUID) -> Data? {
        get { self[CaptureKey.self] }
        set { self[CaptureKey.self] = newValue }
    }
}

extension View {
    @ViewBuilder func dialVersionCaptureBoundary() -> some View {
        #if canImport(UIKit)
        modifier(CaptureBoundary())
        #else
        self
        #endif
    }
}
