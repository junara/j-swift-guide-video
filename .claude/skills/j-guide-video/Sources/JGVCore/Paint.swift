// 塗り・線の色。SVG と同じ書き方の文字列 ("#353b35" / "#fff" / "none" / "rgba(0,0,0,0.3)" / "white") から作れる。
// 文字列リテラルをそのまま渡せる: path(d, fill: "#f3ead7")、palette.primary も Paint
import CoreGraphics
import Foundation

public struct RGBA: Equatable, Hashable, Sendable {
  public var r: Double, g: Double, b: Double, a: Double
  public init(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) {
    self.r = r; self.g = g; self.b = b; self.a = a
  }
  public var cgColor: CGColor { CGColor(srgbRed: r, green: g, blue: b, alpha: a) }
  /// "#rrggbb"
  public var hex: String {
    let c = { (v: Double) in String(format: "%02x", Int((min(1, max(0, v)) * 255).rounded())) }
    return "#" + c(r) + c(g) + c(b)
  }
}

/// 線形グラデーション。units が .objectBoundingBox (SVG の既定) なら x1〜y2 は図形の外接矩形に対する 0〜1
public struct LinearGradient: Equatable, Sendable {
  public enum Units: Sendable { case objectBoundingBox, userSpaceOnUse }
  public var x1: Double, y1: Double, x2: Double, y2: Double
  public var stops: [(offset: Double, color: RGBA)]
  public var units: Units
  /// グラデーションの座標に掛ける変形 (SVG の gradientTransform。units の座標 (0〜1 か図形の座標) → 図形の座標)
  public var transform: CGAffineTransform
  public init(x1: Double = 0, y1: Double = 0, x2: Double = 1, y2: Double = 0, stops: [(Double, Paint)], units: Units = .objectBoundingBox,
              transform: CGAffineTransform = .identity) {
    self.x1 = x1; self.y1 = y1; self.x2 = x2; self.y2 = y2
    self.stops = stops.map { ($0.0, $0.1.rgba ?? RGBA(0, 0, 0, 0)) }
    self.units = units
    self.transform = transform
  }
  public static func == (a: LinearGradient, b: LinearGradient) -> Bool {
    a.x1 == b.x1 && a.y1 == b.y1 && a.x2 == b.x2 && a.y2 == b.y2 && a.units == b.units && a.transform == b.transform
      && a.stops.count == b.stops.count && zip(a.stops, b.stops).allSatisfy { $0.offset == $1.offset && $0.color == $1.color }
  }
}

public enum Paint: Equatable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
  case none
  case color(RGBA)
  case linear(LinearGradient)

  public init(stringLiteral value: String) { self = Paint.parse(value) }
  public init(_ value: String) { self = Paint.parse(value) }

  public static let black = Paint.color(RGBA(0, 0, 0))
  public static let white = Paint.color(RGBA(1, 1, 1))

  public var rgba: RGBA? {
    if case let .color(c) = self { return c }
    if case let .linear(g) = self { return g.stops.first?.color }
    return nil
  }

  public var isNone: Bool { if case .none = self { return true }; return false }

  public var description: String {
    switch self {
    case .none: return "none"
    case let .color(c):
      // hex と同じ丸め (切り捨てると 0.5 → 127 になり、読み戻した色がずれる)
      let v = { (x: Double) in Int((min(1, max(0, x)) * 255).rounded()) }
      return c.a < 1 ? "rgba(\(v(c.r)),\(v(c.g)),\(v(c.b)),\(c.a))" : c.hex
    case .linear: return "linearGradient"
    }
  }

  /// 透明度を掛けた色
  public func opacity(_ o: Double) -> Paint {
    switch self {
    case .none: return .none
    case var .color(c): c.a *= o; return .color(c)
    case var .linear(g): g.stops = g.stops.map { ($0.offset, RGBA($0.color.r, $0.color.g, $0.color.b, $0.color.a * o)) }; return .linear(g)
    }
  }

  /// 2 色の補間 (t = 0 で self、1 で other)
  public func mix(_ other: Paint, _ t: Double) -> Paint {
    guard let a = rgba, let b = other.rgba else { return t < 0.5 ? self : other }
    return .color(RGBA(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t))
  }

  static let named: [String: RGBA] = [
    "black": RGBA(0, 0, 0), "white": RGBA(1, 1, 1), "red": RGBA(1, 0, 0), "green": RGBA(0, 0.5, 0), "blue": RGBA(0, 0, 1),
    "gray": RGBA(0.5, 0.5, 0.5), "grey": RGBA(0.5, 0.5, 0.5), "yellow": RGBA(1, 1, 0), "orange": RGBA(1, 0.647, 0),
    "transparent": RGBA(0, 0, 0, 0),
  ]

  public static func parse(_ raw: String) -> Paint {
    let s = raw.trimmingCharacters(in: .whitespaces).lowercased()
    if s.isEmpty || s == "none" { return .none }
    if s.hasPrefix("#") {
      let h = Array(s.dropFirst())
      func v(_ str: String) -> Double { Double(Int(str, radix: 16) ?? 0) / 255 }
      switch h.count {
      case 3, 4:
        let p = h.map { String([$0, $0]) }
        return .color(RGBA(v(p[0]), v(p[1]), v(p[2]), h.count == 4 ? v(p[3]) : 1))
      case 6, 8:
        let p = stride(from: 0, to: h.count, by: 2).map { String(h[$0 ..< $0 + 2]) }
        return .color(RGBA(v(p[0]), v(p[1]), v(p[2]), h.count == 8 ? v(p[3]) : 1))
      default: return .none
      }
    }
    if s.hasPrefix("rgb") {
      let inner = s.drop { $0 != "(" }.dropFirst().prefix { $0 != ")" }
      // 色は 0〜255 か %、透明度 (4 つ目) は 0〜1 か %
      let parts = inner.split(whereSeparator: { $0 == "," || $0 == " " || $0 == "/" }).map { $0.trimmingCharacters(in: .whitespaces) }
      let nums = parts.enumerated().compactMap { k, t -> Double? in
        if t.hasSuffix("%") { return (Double(t.dropLast()) ?? 0) / 100 * (k < 3 ? 255 : 1) }
        return Double(t)
      }
      guard nums.count >= 3 else { return .none }
      return .color(RGBA(nums[0] / 255, nums[1] / 255, nums[2] / 255, nums.count > 3 ? min(1, max(0, nums[3])) : 1))
    }
    if let c = named[s] { return .color(c) }
    return .color(RGBA(0, 0, 0))
  }
}
