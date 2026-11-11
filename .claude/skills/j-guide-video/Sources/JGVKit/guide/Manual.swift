// 組み立て説明書型 (layout: "guide-manual") の部品: 等角図 (アイソメトリック) の板、点線の矢印、回転の矢印、部品記号、部品リスト。
// 線画 (黒い線 + 薄い塗り) で描く。
import Foundation

/// 組み立て説明書の線の色
public let MANUAL_LINE: Paint = "#2b2f33"
private let LINE = MANUAL_LINE

/// 等角図の投影。ox, oy = 画面上の原点、s = 1 単位 (cm など) あたりの px
public struct Iso {
  public var ox: Double
  public var oy: Double
  public var s: Double
  public init(ox: Double, oy: Double, s: Double) { self.ox = ox; self.oy = oy; self.s = s }
}

/// 3D 座標 (x: 右下へ、y: 左下へ、z: 上へ) → 画面座標
public func isoPoint(_ iso: Iso, _ x: Double, _ y: Double, _ z: Double) -> Pt {
  Pt(iso.ox + (x - y) * 0.866 * iso.s, iso.oy + (x + y) * 0.5 * iso.s - z * iso.s)
}

/// 色を暗くする (k < 1)
private func isoShade(_ p: Paint, _ k: Double) -> Paint {
  guard let c = p.rgba else { return p }
  let ch = { (v: Double) in jsRound((v * 255).rounded() * k) / 255 }
  return .color(RGBA(ch(c.r), ch(c.g), ch(c.b), 1))
}

/// 直方体 (板・箱)。[x, y, z] から幅 w (x 方向)・奥行き d (y 方向)・高さ h。
/// 見える 3 面 (上・左手前・右手前) を描く。fill は基本色、面ごとに明るさを変える
public func IsoBox(iso: Iso, x: Double, y: Double, z: Double, w: Double, d: Double, h: Double, fill: Paint = "#f1e6d2", opacity: Double = 1, dashed: Bool = false) {
  let p = { (a: Double, b: Double, c: Double) in isoPoint(iso, a, b, c) }
  // 小数 1 桁に丸める (元の SVG の points と同じ)
  let r1 = { (q: Pt) in Pt((q.x * 10).rounded() / 10, (q.y * 10).rounded() / 10) }
  let top = [p(x, y, z + h), p(x + w, y, z + h), p(x + w, y + d, z + h), p(x, y + d, z + h)].map(r1)
  let left = [p(x, y + d, z), p(x + w, y + d, z), p(x + w, y + d, z + h), p(x, y + d, z + h)].map(r1)
  let right = [p(x + w, y, z), p(x + w, y + d, z), p(x + w, y + d, z + h), p(x + w, y, z + h)].map(r1)
  let dash: [Double]? = dashed ? [10, 8] : nil
  g(opacity: opacity) {
    polygon(points: left, fill: dashed ? "none" : isoShade(fill, 0.92), stroke: LINE, strokeWidth: 3, strokeLinejoin: .round, strokeDasharray: dash)
    polygon(points: right, fill: dashed ? "none" : isoShade(fill, 0.8), stroke: LINE, strokeWidth: 3, strokeLinejoin: .round, strokeDasharray: dash)
    polygon(points: top, fill: dashed ? "none" : fill, stroke: LINE, strokeWidth: 3, strokeLinejoin: .round, strokeDasharray: dash)
  }
}

/// 部品をずらした位置から定位置へ動かす量 (at から spring で 1 → 0)
public func useAssemble(_ at: Double) -> Double {
  let frame = useCurrentFrame()
  let fps = useVideoConfig().fps
  return 1 - spring(frame: frame - at, fps: fps, damping: 18, stiffness: 90)
}

/// 点線の矢印 (progress 0〜1 で伸びる)
public func DashArrow(from: Pt, to: Pt, progress: Double = 1, color: Paint = MANUAL_LINE, width: Double = 4) {
  if progress <= 0 { return }
  let e = Pt(from.x + (to.x - from.x) * progress, from.y + (to.y - from.y) * progress)
  let a = atan2(e.y - from.y, e.x - from.x)
  let hl = 20.0
  g(fill: "none", stroke: color, strokeWidth: width, strokeLinecap: .round) {
    line(x1: from.x, y1: from.y, x2: e.x, y2: e.y, strokeDasharray: [12, 10])
    path("M \(e.x - cos(a - 0.45) * hl) \(e.y - sin(a - 0.45) * hl) L \(e.x) \(e.y) L \(e.x - cos(a + 0.45) * hl) \(e.y - sin(a + 0.45) * hl)", strokeLinejoin: .round)
  }
}

/// 回す向きの矢印 (時計回り)。spin = true で回り続ける
public func RotateArrow(x: Double, y: Double, r: Double = 34, spin: Bool = false, color: Paint? = nil, opacity: Double = 1) {
  let frame = useCurrentFrame()
  let c = color ?? useGuide().palette.primary
  let rot = spin ? frame * 12 : 0
  g(fill: "none", stroke: c, strokeWidth: 6, strokeLinecap: .round, opacity: opacity, transform: [.translate(x, y), .rotate(rot)]) {
    path("M \(r) 0 A \(r) \(r) 0 1 1 \(r * cos(-0.9)) \(r * sin(-0.9))")
    path("M \(r * cos(-0.9) - 14) \(r * sin(-0.9) - 4) L \(r * cos(-0.9)) \(r * sin(-0.9)) L \(r * cos(-0.9) - 2) \(r * sin(-0.9) + 14)", strokeLinejoin: .round)
  }
}

/// 部品記号 (丸囲みのアルファベット) と引き出し線
public func PartTag(x: Double, y: Double, letter: String, to: Pt? = nil, opacity: Double = 1) {
  let palette = useGuide().palette
  g(opacity: opacity) {
    if let to {
      line(x1: x, y1: y, x2: to.x, y2: to.y, stroke: LINE, strokeWidth: 2)
      circle(cx: to.x, cy: to.y, r: 4, fill: LINE)
    }
    circle(cx: x, cy: y, r: 24, fill: "#fff", stroke: palette.primary, strokeWidth: 4)
    T(letter, x: x, y: y, size: 26, weight: 900, color: palette.primary)
  }
}

/// ネジ (真横から見た小さな図)
public func Screw(x: Double, y: Double, angle: Double = 0, scale: Double = 1) {
  g(stroke: LINE, strokeWidth: 2.5, strokeLinejoin: .round, transform: [.translate(x, y), .rotate(angle), .scale(scale)]) {
    rect(x: -14, y: -6, width: 8, height: 12, rx: 2, fill: "#d9dde1")
    path("M -6 -3 H 18 L 22 0 L 18 3 H -6 Z", fill: "#eef0f2")
    for t in [-1.0, 4, 9, 14] { line(x1: t, y1: -3, x2: t + 3, y2: 3, strokeWidth: 1.5) }
  }
}

/// ドライバー (tip = 先端、angle = 柄の向き (度)、spin = 回転中)
public func Screwdriver(tip: Pt, angle: Double = -30, spin: Bool = false) {
  let frame = useCurrentFrame()
  let palette = useGuide().palette
  let twist = spin ? sin(frame * 0.8) * 6 : 0
  g(stroke: LINE, strokeWidth: 3, strokeLinejoin: .round, transform: [.translate(tip.x, tip.y), .rotate(angle + twist)]) {
    rect(x: 0, y: -4, width: 110, height: 8, fill: "#d9dde1")
    rect(x: 110, y: -16, width: 120, height: 32, rx: 14, fill: palette.accent)
    path("M 130 -8 H 210 M 130 8 H 210", strokeWidth: 2, opacity: 0.5)
  }
}

/// 部品リストの 1 行
public struct PartsListItem {
  public var letter: String
  public var name: String
  public var qty: String
  public var at: Double
  public init(letter: String, name: String, qty: String, at: Double) { self.letter = letter; self.name = name; self.qty = qty; self.at = at }
}

/// 部品リスト (右側のパネル)。items が at で順に強調される
public func PartsList(x: Double, y: Double, w: Double, title: String? = nil, items: [PartsListItem]) {
  // 見出しの既定は言語別 (日本語なら「部品」)
  let title = title ?? guideLabels(useGuide().lang).parts
  let frame = useCurrentFrame()
  let fps = useVideoConfig().fps
  let palette = useGuide().palette
  let rowH = 70.0
  LayoutProbe.group(.chrome, "部品リスト", rect: CGRect(x: x, y: y, width: w, height: 80 + Double(items.count) * rowH)) {
    rect(x: x, y: y, width: w, height: 80 + Double(items.count) * rowH, rx: 16, fill: "#fff", stroke: LINE, strokeWidth: 3)
    T(title, x: x + 28, y: y + 40, size: 30, weight: 900, color: LINE, anchor: .start)
    line(x1: x + 20, y1: y + 72, x2: x + w - 20, y2: y + 72, stroke: LINE, strokeWidth: 2)
    for (i, it) in items.enumerated() {
      let s = spring(frame: frame - it.at, fps: fps, damping: 200)
      let hl = interpolate(frame - it.at, [0, 6, 30, 45], [0, 1, 1, 0.25], .clamp)
      let yy = y + 80 + Double(i) * rowH
      g(opacity: 0.25 + 0.75 * s) {
        rect(x: x + 10, y: yy + 4, width: w - 20, height: rowH - 8, rx: 10, fill: palette.primary, opacity: 0.12 * hl)
        circle(cx: x + 50, cy: yy + rowH / 2, r: 22, fill: "#fff", stroke: palette.primary, strokeWidth: 3.5)
        T(it.letter, x: x + 50, y: yy + rowH / 2, size: 24, weight: 900, color: palette.primary)
        T(it.name, x: x + 90, y: yy + rowH / 2, size: 26, weight: 700, color: LINE, anchor: .start)
        T(it.qty, x: x + w - 30, y: yy + rowH / 2, size: 28, weight: 900, color: LINE, anchor: .end)
      }
    }
  }
}
