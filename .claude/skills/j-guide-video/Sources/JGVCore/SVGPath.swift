// SVG のパスデータ ("M 0 0 L 10 10 Q … A … Z") を CGPath にする。
// コマンドは M L H V C S Q T A Z (大文字 = 絶対座標、小文字 = 相対座標) と、その省略 (座標の繰り返し) に対応する
import CoreGraphics
import Foundation

public enum SVGPath {
  // 解析結果のキャッシュ (同じ文字列のパスはフレームをまたいで何度も描くので)
  nonisolated(unsafe) private static var cache: [String: CGPath] = [:]
  private static let lock = NSLock()

  public static func parse(_ d: String) -> CGPath {
    lock.lock()
    if let p = cache[d] { lock.unlock(); return p }
    lock.unlock()
    let p = build(d)
    lock.lock()
    if cache.count > 20000 { cache.removeAll(keepingCapacity: true) }
    cache[d] = p
    lock.unlock()
    return p
  }

  private struct Scanner {
    let s: [UInt8]
    var i = 0
    init(_ str: String) { s = Array(str.utf8) }

    mutating func skipSeparators() {
      while i < s.count, s[i] == 32 || s[i] == 44 || s[i] == 9 || s[i] == 10 || s[i] == 13 { i += 1 }
    }

    var atEnd: Bool { mutating get { skipSeparators(); return i >= s.count } }

    mutating func peekIsNumber() -> Bool {
      skipSeparators()
      guard i < s.count else { return false }
      let c = s[i]
      return (c >= 48 && c <= 57) || c == 45 || c == 43 || c == 46
    }

    mutating func command() -> UInt8? {
      skipSeparators()
      guard i < s.count else { return nil }
      let c = s[i]
      if (c >= 65 && c <= 90) || (c >= 97 && c <= 122), c != 101, c != 69 {
        i += 1
        return c
      }
      return nil
    }

    /// 弧の大小・向きのフラグ (区切りなしの "01" も 1 字ずつ読む)
    mutating func flag() -> Double {
      skipSeparators()
      guard i < s.count else { return 0 }
      let c = s[i]
      i += 1
      return c == 49 ? 1 : 0
    }

    mutating func number() -> Double {
      skipSeparators()
      let start = i
      if i < s.count, s[i] == 45 || s[i] == 43 { i += 1 }
      var seenDot = false
      while i < s.count {
        let c = s[i]
        if c >= 48 && c <= 57 { i += 1; continue }
        if c == 46, !seenDot { seenDot = true; i += 1; continue }
        break
      }
      if i < s.count, s[i] == 101 || s[i] == 69 {
        var j = i + 1
        if j < s.count, s[j] == 45 || s[j] == 43 { j += 1 }
        if j < s.count, s[j] >= 48 && s[j] <= 57 {
          i = j
          while i < s.count, s[i] >= 48 && s[i] <= 57 { i += 1 }
        }
      }
      if start == i {
        // 引数が足りないまま次のコマンドの文字が来たら、進めずに 0 を返す (次の周回で command() が読む)。それ以外の読めない文字は飛ばす
        if i < s.count, (s[i] >= 65 && s[i] <= 90) || (s[i] >= 97 && s[i] <= 122) { return 0 }
        i += 1
        return 0
      }
      // 範囲を超える数 ("1e999") は inf になり、円弧の計算で NaN → Int() で落ちるので 0 にする
      let v = Double(String(decoding: s[start ..< i], as: UTF8.self)) ?? 0
      return v.isFinite ? v : 0
    }
  }

  static func build(_ d: String) -> CGPath {
    let path = CGMutablePath()
    var sc = Scanner(d)
    var cur = CGPoint.zero
    var start = CGPoint.zero
    var lastCtrl: CGPoint? = nil
    var lastCmd: UInt8 = 0
    var cmd: UInt8 = 0
    var hasCurrent = false

    func ensureStart() {
      if !hasCurrent { path.move(to: cur); start = cur; hasCurrent = true }
    }

    while true {
      if let c = sc.command() {
        cmd = c
      } else if sc.peekIsNumber(), cmd != 0, cmd != 90, cmd != 122 {
        // 座標の繰り返し: M の後は L として扱う (Z は引数を取らないので、Z の後の数は読み飛ばす。繰り返すと無限ループになる)
        if cmd == 77 { cmd = 76 } else if cmd == 109 { cmd = 108 }
      } else {
        if sc.atEnd { break }
        sc.i += 1
        continue
      }
      let rel = cmd >= 97
      let base = rel ? cur : .zero
      switch cmd {
      case 77, 109: // M
        let p = CGPoint(x: base.x + sc.number(), y: base.y + sc.number())
        path.move(to: p)
        cur = p; start = p; hasCurrent = true
        lastCtrl = nil
      case 76, 108: // L
        ensureStart()
        let p = CGPoint(x: base.x + sc.number(), y: base.y + sc.number())
        path.addLine(to: p); cur = p; lastCtrl = nil
      case 72, 104: // H
        ensureStart()
        let x = sc.number()
        let p = CGPoint(x: rel ? cur.x + x : x, y: cur.y)
        path.addLine(to: p); cur = p; lastCtrl = nil
      case 86, 118: // V
        ensureStart()
        let y = sc.number()
        let p = CGPoint(x: cur.x, y: rel ? cur.y + y : y)
        path.addLine(to: p); cur = p; lastCtrl = nil
      case 67, 99: // C
        ensureStart()
        let c1 = CGPoint(x: base.x + sc.number(), y: base.y + sc.number())
        let c2 = CGPoint(x: base.x + sc.number(), y: base.y + sc.number())
        let p = CGPoint(x: base.x + sc.number(), y: base.y + sc.number())
        path.addCurve(to: p, control1: c1, control2: c2)
        cur = p; lastCtrl = c2
      case 83, 115: // S
        ensureStart()
        let c1: CGPoint
        if let lc = lastCtrl, [67, 99, 83, 115].contains(lastCmd) { c1 = CGPoint(x: 2 * cur.x - lc.x, y: 2 * cur.y - lc.y) } else { c1 = cur }
        let c2 = CGPoint(x: base.x + sc.number(), y: base.y + sc.number())
        let p = CGPoint(x: base.x + sc.number(), y: base.y + sc.number())
        path.addCurve(to: p, control1: c1, control2: c2)
        cur = p; lastCtrl = c2
      case 81, 113: // Q
        ensureStart()
        let c = CGPoint(x: base.x + sc.number(), y: base.y + sc.number())
        let p = CGPoint(x: base.x + sc.number(), y: base.y + sc.number())
        path.addQuadCurve(to: p, control: c)
        cur = p; lastCtrl = c
      case 84, 116: // T
        ensureStart()
        let c: CGPoint
        if let lc = lastCtrl, [81, 113, 84, 116].contains(lastCmd) { c = CGPoint(x: 2 * cur.x - lc.x, y: 2 * cur.y - lc.y) } else { c = cur }
        let p = CGPoint(x: base.x + sc.number(), y: base.y + sc.number())
        path.addQuadCurve(to: p, control: c)
        cur = p; lastCtrl = c
      case 65, 97: // A
        ensureStart()
        let rx = sc.number(), ry = sc.number(), rot = sc.number()
        let large = sc.flag(), sweep = sc.flag()
        let p = CGPoint(x: base.x + sc.number(), y: base.y + sc.number())
        addArc(path, from: cur, to: p, rx: rx, ry: ry, rotation: rot, large: large != 0, sweep: sweep != 0)
        cur = p; lastCtrl = nil
      case 90, 122: // Z
        if hasCurrent { path.closeSubpath() }
        cur = start; lastCtrl = nil
        hasCurrent = false
        // Z の後に M 無しで続くコマンドは、閉じた点から始まる
        path.move(to: cur); hasCurrent = true
      default:
        _ = sc.number()
      }
      lastCmd = cmd
    }
    return path
  }

  /// SVG の弧 (端点で指定) を 3 次ベジェで近似して足す (SVG 1.1 F.6.5 の中心の求め方)
  static func addArc(_ path: CGMutablePath, from p0: CGPoint, to p1: CGPoint, rx rxIn: Double, ry ryIn: Double, rotation: Double, large: Bool, sweep: Bool) {
    if p0 == p1 { return }
    var rx = abs(rxIn), ry = abs(ryIn)
    if rx == 0 || ry == 0 { path.addLine(to: p1); return }
    let phi = rotation * .pi / 180
    let cosP = cos(phi), sinP = sin(phi)
    let dx = (p0.x - p1.x) / 2, dy = (p0.y - p1.y) / 2
    let x1p = cosP * dx + sinP * dy
    let y1p = -sinP * dx + cosP * dy
    let lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
    if lambda > 1 { let s = sqrt(lambda); rx *= s; ry *= s }
    let num = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p
    let den = rx * rx * y1p * y1p + ry * ry * x1p * x1p
    var coef = den == 0 ? 0 : sqrt(max(0, num / den))
    if large == sweep { coef = -coef }
    let cxp = coef * (rx * y1p / ry)
    let cyp = coef * -(ry * x1p / rx)
    let cx = cosP * cxp - sinP * cyp + (p0.x + p1.x) / 2
    let cy = sinP * cxp + cosP * cyp + (p0.y + p1.y) / 2
    func angle(_ ux: Double, _ uy: Double, _ vx: Double, _ vy: Double) -> Double {
      let a = atan2(ux * vy - uy * vx, ux * vx + uy * vy)
      return a
    }
    let theta1 = angle(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry)
    var dtheta = angle((x1p - cxp) / rx, (y1p - cyp) / ry, (-x1p - cxp) / rx, (-y1p - cyp) / ry)
    if !sweep && dtheta > 0 { dtheta -= 2 * .pi } else if sweep && dtheta < 0 { dtheta += 2 * .pi }
    // 有限でない値が入ったら (極端な値の組み合わせ)、円弧をあきらめて直線にする
    guard dtheta.isFinite, cx.isFinite, cy.isFinite, theta1.isFinite, rx.isFinite, ry.isFinite else { path.addLine(to: p1); return }
    let segs = max(1, Int(ceil(abs(dtheta) / (.pi / 2) - 1e-9)))
    let delta = dtheta / Double(segs)
    let t = 4.0 / 3.0 * tan(delta / 4)
    func pt(_ th: Double) -> CGPoint {
      let x = rx * cos(th), y = ry * sin(th)
      return CGPoint(x: cx + cosP * x - sinP * y, y: cy + sinP * x + cosP * y)
    }
    func deriv(_ th: Double) -> CGPoint {
      let x = -rx * sin(th), y = ry * cos(th)
      return CGPoint(x: cosP * x - sinP * y, y: sinP * x + cosP * y)
    }
    var th = theta1
    for k in 0 ..< segs {
      let th2 = th + delta
      let a = pt(th), b = k == segs - 1 ? p1 : pt(th2)
      let da = deriv(th), db = deriv(th2)
      path.addCurve(to: b, control1: CGPoint(x: a.x + t * da.x, y: a.y + t * da.y), control2: CGPoint(x: b.x - t * db.x, y: b.y - t * db.y))
      th = th2
    }
  }
}

// ---------- パスの長さ・途中の点 (線を描くアニメーション、パスに沿って動かす) ----------

/// パスを折れ線に分けて長さを測る
public struct PathMeasure {
  public private(set) var points: [CGPoint] = []
  public private(set) var cumulative: [Double] = []
  public var length: Double { cumulative.last ?? 0 }

  public init(_ path: CGPath) {
    var pts: [CGPoint] = []
    var cum: [Double] = []
    var cur = CGPoint.zero
    var start = CGPoint.zero
    var total = 0.0
    func add(_ p: CGPoint, newSub: Bool = false) {
      if !newSub, let last = pts.last { total += hypot(p.x - last.x, p.y - last.y) }
      pts.append(p); cum.append(total)
    }
    path.applyWithBlock { el in
      let e = el.pointee
      switch e.type {
      case .moveToPoint:
        cur = e.points[0]; start = cur
        add(cur, newSub: true)
      case .addLineToPoint:
        cur = e.points[0]; add(cur)
      case .addQuadCurveToPoint:
        let c = e.points[0], p = e.points[1], p0 = cur
        for k in 1 ... 16 {
          let t = Double(k) / 16
          let x = (1 - t) * (1 - t) * p0.x + 2 * (1 - t) * t * c.x + t * t * p.x
          let y = (1 - t) * (1 - t) * p0.y + 2 * (1 - t) * t * c.y + t * t * p.y
          add(CGPoint(x: x, y: y))
        }
        cur = p
      case .addCurveToPoint:
        let c1 = e.points[0], c2 = e.points[1], p = e.points[2], p0 = cur
        for k in 1 ... 24 {
          let t = Double(k) / 24, u = 1 - t
          let x = u * u * u * p0.x + 3 * u * u * t * c1.x + 3 * u * t * t * c2.x + t * t * t * p.x
          let y = u * u * u * p0.y + 3 * u * u * t * c1.y + 3 * u * t * t * c2.y + t * t * t * p.y
          add(CGPoint(x: x, y: y))
        }
        cur = p
      case .closeSubpath:
        cur = start; add(cur)
      @unknown default: break
      }
    }
    points = pts
    cumulative = cum
  }

  public init(_ d: String) { self.init(SVGPath.parse(d)) }

  /// 先頭から長さ s の点
  public func point(at s: Double) -> CGPoint? {
    guard !points.isEmpty else { return nil }
    if s <= 0 { return points[0] }
    if s >= length { return points[points.count - 1] }
    var lo = 0, hi = cumulative.count - 1
    while lo < hi - 1 {
      let mid = (lo + hi) / 2
      if cumulative[mid] < s { lo = mid } else { hi = mid }
    }
    let seg = cumulative[hi] - cumulative[lo]
    let t = seg <= 0 ? 0 : (s - cumulative[lo]) / seg
    let a = points[lo], b = points[hi]
    return CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
  }
}

/// パスの長さ
public func getLength(_ d: String) -> Double { PathMeasure(d).length }

/// パスの先頭から長さ s の点
public func getPointAtLength(_ d: String, _ s: Double) -> Pt? {
  PathMeasure(d).point(at: s).map { Pt($0.x, $0.y) }
}

/// progress (0→1) だけ線を描いた状態の破線
public func evolvePath(_ progress: Double, _ d: String) -> (dash: [Double], offset: Double) {
  let len = getLength(d)
  return ([len, len], len - progress * len)
}
