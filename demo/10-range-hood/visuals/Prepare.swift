// 掃除道具を準備する: 句ごとにゴム手袋・スポンジ・歯ブラシ・中性洗剤・ぬるま湯・雑巾・タオル・新聞紙が落ちてきて並ぶ → 新聞紙を広げて敷く
import JGVKit

private struct Tool {
  var w: Double
  var label: String
  var draw: (Double, Double) -> Void
}

private let TOOLS: [Tool] = [
  Tool(w: 90, label: "ゴム手袋", draw: { x, y in Glove(x: x, y: y, scale: 0.8) }),
  Tool(w: 110, label: "スポンジ", draw: { x, y in Sponge(x: x, y: y, scale: 0.9) }),
  Tool(w: 130, label: "歯ブラシ", draw: { x, y in ToothBrush(x: x + 8, y: y, scale: 0.72) }),
  Tool(w: 80, label: "中性洗剤", draw: { x, y in Detergent(x: x, y: y, scale: 0.72) }),
  Tool(w: 130, label: "ぬるま湯", draw: { x, y in Basin(x: x, y: y, scale: 0.66, steam: true) }),
  Tool(w: 120, label: "雑巾", draw: { x, y in Rag(x: x, y: y, scale: 0.95) }),
  Tool(w: 120, label: "乾いたタオル", draw: { x, y in Towel(x: x, y: y, scale: 0.95) }),
  Tool(w: 120, label: "新聞紙", draw: { x, y in NewsBundle(x: x, y: y, scale: 0.95) }),
]
private func toolX(_ i: Int) -> Double { 690 + Double(i) * 150 }

func Prepare(_ props: Props) {
  let n = useNarration()
  let palette = useGuide().palette
  let cur = TOOLS.indices.first { n.frame < n.atPhrase(1, $0 + 1) } ?? -1
  // 3 行目: 新聞紙の束を手に取り、天板に広げる
  let spreadAt = n.atPhrase(2, 0, 0.3)
  let spread = interpolate(n.frame, [spreadAt, n.endOf(2) - 6], [0, 1], .clamp)
  let bundleGone = interpolate(n.frame, [spreadAt - 4, spreadAt + 6], [1, 0], .clamp)
  let sheetEdge = Pt(NEWS.x - NEWS.w / 2 + NEWS.w * spread, NEWS.y + 20)
  var handR = mix(PRESENTER.restR, PRESENTER.gestureR, n.ease(0, 0.2))
  if n.frame >= n.at(2, -0.4) { handR = mix(handR, spread > 0 ? sheetEdge : Pt(toolX(7), GUIDE.counterY - 30), n.ease(2, -0.4)) }

  Stage {
    Outlet(x: OUTLET.x, y: OUTLET.y)
    Plug(x: PLUG_IN.x, y: PLUG_IN.y, cordFrom: CORD_FROM)
    RangeHood(x: HOOD.x, y: HOOD.y, dirt: 0.9, oil: 1, gaps: 0.8)
    NewsSheet(x: NEWS.x, y: NEWS.y, w: NEWS.w, spread: spread)
    for (i, tool) in TOOLS.enumerated() {
      let x = toolX(i)
      let at = n.atPhrase(1, i)
      let s = spring(frame: n.frame - at, fps: n.fps, damping: 14, stiffness: 140)
      let y = GUIDE.counterY - (1 - s) * 420
      let op = interpolate(n.frame, [at - 2, at + 3], [0, 1], .clamp) * (i == 7 ? bundleGone : 1)
      let active = n.frame >= at && i == (cur < 0 ? -1 : cur)
      let bob = active ? sin(n.sec * 6) * 4 : 0
      let ly = GUIDE.counterY + (i % 2 == 0 ? 30 : 68)
      let lw = textWidth(tool.label, 22) + 28
      g(opacity: op) {
        g(opacity: s) {
          Shadow(x: x, w: tool.w)
        }
        g(transform: [.translate(0, bob)]) { tool.draw(x, y) }
        g(opacity: interpolate(n.frame, [at + 6, at + 14], [0, 1], .clamp)) {
          rect(x: x - lw / 2, y: ly - 17, width: lw, height: 34, rx: 17, fill: active ? palette.primary : "#fff", stroke: palette.ink, strokeWidth: 3)
          T(tool.label, x: x, y: ly, size: 22, weight: 800, color: active ? "#fff" : palette.ink)
        }
      }
    }
    Worker(handR: handR)
  }
}
