import SwiftUI
import AppKit

/// Brand marks synced from `white-icon/`, `color-icon/`, and horizontal SVGs at build time.
enum BrandImage {
    private static func resourceURL(named name: String, ext: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: ext)
            ?? Bundle.module.url(forResource: name, withExtension: ext)
    }

    private static func png(named name: String, template: Bool = false) -> NSImage? {
        guard let url = resourceURL(named: name, ext: "png"),
              let image = NSImage(contentsOf: url) else { return nil }
        image.isTemplate = template
        return image
    }

    private static func resized(_ image: NSImage, to size: NSSize, template: Bool) -> NSImage {
        let copy = NSImage(size: size)
        copy.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(
            in: NSRect(origin: .zero, size: size),
            from: NSRect(origin: .zero, size: image.size),
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: true,
            hints: nil
        )
        copy.unlockFocus()
        copy.isTemplate = template
        return copy
    }

    private static func image(
        resource: String,
        fitting size: NSSize,
        fallback: String,
        template: Bool = false
    ) -> Image {
        guard let source = png(named: resource, template: template) else {
            return Image(systemName: fallback)
        }
        return Image(nsImage: resized(source, to: size, template: template))
    }

    /// Menu bar — white icon, template-tinted for light/dark menu bar.
    static var menuBarIcon: Image {
        image(resource: "app-icon-white-32", fitting: NSSize(width: 18, height: 18),
              fallback: "externaldrive.connected.to.line.below", template: true)
    }

    /// Panel header — white compact mark.
    static var headerLogo: Image {
        image(resource: "app-icon-white-32", fitting: NSSize(width: 22, height: 22),
              fallback: "externaldrive.connected.to.line.below")
    }

    /// About / welcome — full-color app logo.
    static var heroIcon: Image {
        image(resource: "app-icon-color-128", fitting: NSSize(width: 64, height: 64),
              fallback: "externaldrive.connected.to.line.below")
    }

    @MainActor
    static func applyAppIcon() {
        guard let source = png(named: "app-icon-color-512") else { return }
        NSApp.applicationIconImage = source
    }
}
