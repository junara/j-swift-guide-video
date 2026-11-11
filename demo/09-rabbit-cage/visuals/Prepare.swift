// 道具を準備する: 句ごとにゴミ袋・掃除シート・ブラシ・タオル・ペットシーツが落ちてきて並ぶ
import Foundation
import JGVKit

private struct Tool {
  var x: Double
  var w: Double
  var label: String
  var draw: (Double, Double) -> Void
}

private let TOOLS: [Tool] = [
  Tool(x: 690, w: 140, label: "ゴミ袋", draw: { x, y in TrashBag(x: x, y: y) }),
  Tool(x: 915, w: 170, label: "掃除シート", draw: { x, y in WipePack(x: x, y: y) }),
  Tool(x: 1140, w: 130, label: "ブラシ", draw: { x, y in Brush(x: x, y: y) }),
  Tool(x: 1365, w: 160, label: "タオル", draw: { x, y in Towel(x: x, y: y) }),
  Tool(x: 1600, w: 170, label: "ペットシーツ", draw: { x, y in SheetPack(x: x, y: y) }),
]

func Prepare(_ props: Props) {
  let n = useNarration()
  let palette = useGuide().palette
  let cur = TOOLS.indices.first { n.frame < n.atPhrase(1, $0 + 1) } ?? -1
  Stage {
    for (i, tool) in TOOLS.enumerated() {
      let at = n.atPhrase(1, i)
      let s = spring(frame: n.frame - at, fps: n.fps, damping: 14, stiffness: 140)
      let y = GUIDE.counterY - (1 - s) * 420
      let op = interpolate(n.frame, [at - 2, at + 3], [0, 1], .clamp)
      let active = n.frame >= at && i == (cur < 0 ? -1 : cur)
      let bob = active ? sin(n.sec * 6) * 4 : 0
      g(opacity: op) {
        g(opacity: s) {
          Shadow(x: tool.x, w: tool.w)
        }
        g(transform: [.translate(0, bob)]) { tool.draw(tool.x, y) }
        g(opacity: interpolate(n.frame, [at + 6, at + 14], [0, 1], .clamp)) {
          rect(x: tool.x - 95, y: GUIDE.counterY + 26, width: 190, height: 46, rx: 23, fill: active ? palette.primary : "#fff", stroke: palette.ink, strokeWidth: 3)
          T(tool.label, x: tool.x, y: GUIDE.counterY + 49, size: 25, weight: 800, color: active ? "#fff" : palette.ink)
        }
      }
    }
    Presenter(handR: mix(PRESENTER.restR, PRESENTER.gestureR, n.ease(0, 0.2)))
  }
}
