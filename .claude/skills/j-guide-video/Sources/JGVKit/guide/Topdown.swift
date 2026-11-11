// 手元俯瞰型 (layout: "guide-topdown") の部品: 真上から見た道具と手。原点はどれも中心。
import Foundation

/// 置いた物の影 (真上から: 少し右下にずらす)
private func TopShadow(x: Double, y: Double, r: Double, rx: Double? = nil) {
  ellipse(cx: x + r * 0.08, cy: y + r * 0.1, rx: rx ?? r, ry: r, fill: "#6b4a25", opacity: 0.18)
}

/// 輪郭線の属性 (ink の線、太さ 6、角を丸める)
private func inked(_ content: () -> Void) {
  g(stroke: useGuide().palette.ink, strokeWidth: 6, strokeLinecap: .round, strokeLinejoin: .round, content)
}

/// ボウル・茶わん (fill: 中身の色、grains: 粒のテクスチャ)
public func TopBowl(x: Double, y: Double, r: Double, color: Paint = "#f3ede1", fill: Paint? = nil, level: Double = 1, grains: Paint? = nil) {
  let palette = useGuide().palette
  let inner = r * 0.82
  TopShadow(x: x, y: y, r: r)
  inked { circle(cx: x, cy: y, r: r, fill: color) }
  circle(cx: x, cy: y, r: inner, fill: "#e6dccb", stroke: palette.ink, strokeWidth: 3)
  if let fill, level > 0 {
    circle(cx: x, cy: y, r: inner * level.squareRoot() * 0.96, fill: fill)
    if let grains {
      for i in 0 ..< (level.isFinite ? Int(jsRound(40 * min(level, 4))) : 0) {
        let a = random("bg\(i)") * Double.pi * 2
        let d = random("bd\(i)").squareRoot() * inner * level.squareRoot() * 0.85
        let gx = x + cos(a) * d, gy = y + sin(a) * d
        ellipse(cx: gx, cy: gy, rx: 7, ry: 4, fill: grains, transform: [.rotate(random("br\(i)") * 180, gx, gy)])
      }
    }
  }
  circle(cx: x, cy: y, r: r * 0.91, fill: "none", stroke: palette.primary, strokeWidth: 6, opacity: 0.5)
}

/// 皿
public func TopPlate(x: Double, y: Double, r: Double, color: Paint = "#fbf8f1") {
  TopShadow(x: x, y: y, r: r)
  inked { circle(cx: x, cy: y, r: r, fill: color) }
  circle(cx: x, cy: y, r: r * 0.72, fill: "none", stroke: "#e4dccb", strokeWidth: 4)
}

/// 塩・こしょう入れ (shake: 振っている度合い 0〜1)
public func TopShaker(x: Double, y: Double, r: Double = 46, color: Paint = "#f4f1ea", shake: Double = 0) {
  let frame = useCurrentFrame()
  let palette = useGuide().palette
  let dx = shake > 0 ? sin(frame * 1.6) * 10 * shake : 0
  g(transform: [.translate(dx, 0)]) {
    TopShadow(x: x, y: y, r: r)
    inked { circle(cx: x, cy: y, r: r, fill: color) }
    circle(cx: x, cy: y, r: r * 0.6, fill: "#c9ced0", stroke: palette.ink, strokeWidth: 3)
    for i in [-1.0, 0, 1] { for j in [-1.0, 0, 1] { circle(cx: x + i * r * 0.22, cy: y + j * r * 0.22, r: 3, fill: palette.ink) } }
  }
}

/// ふりかけた粒 (塩・ごま・粉)
public func Sprinkle(x: Double, y: Double, r: Double, amount: Double, color: Paint = "#ffffff", seed: String = "sp") {
  for i in 0 ..< max(0, Int(jsRound(40 * amount))) {
    let a = random("\(seed)a\(i)") * Double.pi * 2
    let d = random("\(seed)d\(i)").squareRoot() * r
    circle(cx: x + cos(a) * d, cy: y + sin(a) * d, r: 2.6, fill: color, stroke: "#8a8a7c", strokeWidth: 0.8)
  }
}

/// 手を引っ込めた位置の y (画面の下の外。指先まで隠れる)。height: 画面の高さ (省略すると描いている動画の高さ。横型 1080、縦型 1920)。
/// 手のひらがこれより下なら TopHand は描かない
public func topOffscreenY(_ height: Double? = nil) -> Double { (height ?? RenderContext.currentOrNil?.config.height ?? 1080) + 90 }

public enum HandSide { case L, R }

/// 手の真下 (画面の下の外) の腕の付け根。TopHand の from に渡すと、手を左右に動かしても腕が画面を斜めに横切らない。
/// side: 右手は手より少し右、左手は少し左から伸ばす。height: 画面の高さ (省略すると描いている動画の高さ)
public func topArmFrom(_ to: Pt, _ side: HandSide = .R, _ height: Double? = nil, _ spread: Double = 140) -> Pt {
  Pt(to.x + (side == .R ? spread : -spread), topOffscreenY(height) + 40)
}

/// 真上から見た手。from (画面の端) から袖が伸び、to に手のひらを置く。
/// angle: 指先の向き (度、0 = 上向き)、cup: 手を丸める度合い (0〜1)
public func TopHand(from: Pt, to: Pt, angle: Double? = nil, cup: Double = 0, side: HandSide = .R) {
  let palette = useGuide().palette
  let height = useVideoConfig().height
  // 手のひらが画面の下の外 (引っ込めた所) にあるときは描かない (袖の端が字幕バーの下からのぞかない)
  if to.y > topOffscreenY(height) { return }
  let a = angle ?? (atan2(to.x - from.x, from.y - to.y) * 180) / Double.pi
  let mx = (from.x + to.x) / 2 + (side == .R ? 30 : -30)
  let my = (from.y + to.y) / 2
  let sleeve = "M \(from.x) \(from.y) Q \(mx) \(my) \(to.x) \(to.y)"
  let fl = 46 * (1 - cup * 0.45) // 指の長さ
  g(strokeLinecap: .round) {
    path(sleeve, fill: "none", stroke: palette.ink, strokeWidth: 70)
    path(sleeve, fill: "none", stroke: palette.primary, strokeWidth: 58)
    g(stroke: palette.ink, strokeWidth: 5, strokeLinejoin: .round, transform: [.translate(to.x, to.y), .rotate(a)]) {
      // 指
      for fx in [-24.0, -8, 8, 24] {
        rect(x: fx - 8, y: -30 - fl + abs(fx) * 0.3, width: 16, height: fl + 10, rx: 8, fill: palette.skin)
      }
      // 親指
      rect(x: side == .R ? -52 : 36, y: -24, width: 16, height: 44, rx: 8, fill: palette.skin, transform: [.rotate(side == .R ? -40 : 40, side == .R ? -44 : 44, 0)])
      ellipse(cx: 0, cy: 0, rx: 36, ry: 38, fill: palette.skin)
    }
  }
}


