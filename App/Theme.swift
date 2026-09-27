import AppKit
import CoreText
import SwiftUI

/// Design tokens from DESIGN.md ("the faceplate"), shared with the website's site/style.css.
enum Theme {
    // Colors: dark / light pairs, switched by the window's appearance.
    static let bg = dynamic(0x0E0F11, 0xF4F2ED)
    static let panel = dynamic(0x17191C, 0xFBFAF7)
    static let panel2 = dynamic(0x1D2024, 0xEEEBE4)
    static let line = dynamic(0x2A2D31, 0xDAD6CD)
    static let text = dynamic(0xE8E6E1, 0x16171A)
    static let muted = dynamic(0x8C8A85, 0x66645F)
    static let faint = dynamic(0x5C5B58, 0x9C998F)
    static let amber = Color(hex: 0xF2A33A)                  // the indicator light, fills
    static let amberInk = dynamic(0xF2A33A, 0xA8620A)       // amber text / links
    static let ok = dynamic(0x5FB37A, 0x2F8A4E)
    static let err = dynamic(0xE0604F, 0xC2412F)

    // Fonts, bundled in App/Fonts (OFL) and registered at launch.
    static func serif(_ size: CGFloat) -> Font { .custom("Instrument Serif", size: size) }
    static func sans(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom("Instrument Sans", size: size).weight(weight)
    }
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        .custom("Geist Mono", size: size).weight(weight)
    }

    static func registerFonts() {
        for url in Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [] {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    private static func dynamic(_ dark: UInt32, _ light: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            NSColor(hex: appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light)
        })
    }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

extension Color {
    init(hex: UInt32) { self.init(nsColor: NSColor(hex: hex)) }
}

/// Engraved panel label: small uppercase mono, tracked out, muted.
struct EngravedLabel: View {
    let text: String
    var color = Theme.muted
    init(_ text: String, color: Color = Theme.muted) { self.text = text; self.color = color }
    var body: some View {
        Text(text.uppercased()).font(Theme.mono(10.5)).tracking(1.4).foregroundColor(color)
    }
}

/// The amber indicator light. Off = hollow, for "no device".
struct LED: View {
    var color = Theme.amber
    var lit = true
    var body: some View {
        Circle()
            .fill(lit ? color : .clear)
            .overlay(Circle().stroke(lit ? .clear : Theme.faint, lineWidth: 1))
            .frame(width: 8, height: 8)
            .shadow(color: lit ? color.opacity(0.6) : .clear, radius: 5)
            .accessibilityHidden(true)
    }
}

/// Primary: bone on graphite (ink on paper), amber on hover, like the website's download button.
/// Secondary: hairline outline.
struct FaceplateButtonStyle: ButtonStyle {
    var primary = false
    func makeBody(configuration: Configuration) -> some View {
        Face(configuration: configuration, primary: primary)
    }

    private struct Face: View {
        let configuration: Configuration
        let primary: Bool
        @Environment(\.isEnabled) private var enabled
        @State private var hover = false

        var body: some View {
            configuration.label
                .font(Theme.sans(13, .semibold))
                .foregroundColor(primary ? (hover && enabled ? Color(hex: 0x16171A) : Theme.bg) : Theme.text)
                .padding(.horizontal, 12)
                .frame(minHeight: 28)
                .background(RoundedRectangle(cornerRadius: 7).fill(
                    primary ? (hover && enabled ? Theme.amber : Theme.text) : (hover && enabled ? Theme.panel2 : Theme.panel)))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(primary ? .clear : Theme.line))
                .opacity(enabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
                .contentShape(Rectangle())
                .onHover { hover = $0 }
        }
    }
}

extension ButtonStyle where Self == FaceplateButtonStyle {
    static var faceplate: FaceplateButtonStyle { FaceplateButtonStyle() }
    static var faceplatePrimary: FaceplateButtonStyle { FaceplateButtonStyle(primary: true) }
}
