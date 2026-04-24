import SwiftUI

struct Voice: Codable, Identifiable, Hashable {
    let name: String
    let id: String
    let color: String
    let style: String
    let kind: String
    let hasPortrait: Bool

    enum CodingKeys: String, CodingKey {
        case name, id, color, style, kind
        case hasPortrait = "has_portrait"
    }

    init(
        name: String,
        id: String,
        color: String,
        style: String,
        kind: String = "default",
        hasPortrait: Bool = false
    ) {
        self.name = name
        self.id = id
        self.color = color
        self.style = style
        self.kind = kind
        self.hasPortrait = hasPortrait
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        id = try c.decode(String.self, forKey: .id)
        color = try c.decode(String.self, forKey: .color)
        style = try c.decode(String.self, forKey: .style)
        kind = try c.decodeIfPresent(String.self, forKey: .kind) ?? "default"
        hasPortrait = try c.decodeIfPresent(Bool.self, forKey: .hasPortrait) ?? false
    }

    var swiftUIColor: Color {
        Color(hex: color) ?? .blue
    }
}

extension Color {
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let val = UInt64(s, radix: 16) else { return nil }
        self.init(
            red: Double((val >> 16) & 0xFF) / 255,
            green: Double((val >> 8) & 0xFF) / 255,
            blue: Double(val & 0xFF) / 255
        )
    }

    func toHexString() -> String? {
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? NSColor(self)
        let r = Int(round(ns.redComponent * 255))
        let g = Int(round(ns.greenComponent * 255))
        let b = Int(round(ns.blueComponent * 255))
        return String(format: "#%02x%02x%02x", r, g, b)
    }
}
