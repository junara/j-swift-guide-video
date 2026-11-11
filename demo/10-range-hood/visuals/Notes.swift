// 注意事項: 1 行ごとに注意カード (電源を切る / 転倒 / 水をかけない / 硬いブラシ NG / アルカリ性洗剤 / 機種ごとの違い / ファンの分解)
import JGVKit

private enum Kind { case ok, ng, warn }

private func Mark(x: Double, y: Double, kind: Kind, color: Paint) {
  circle(cx: x, cy: y, r: 20, fill: kind == .ok ? color : kind == .ng ? "#d14b3b" : "#e0a83a", stroke: "#353b35", strokeWidth: 3)
  switch kind {
  case .ok:
    path("M \(x - 9) \(y) l 6 7 l 12 -14", fill: "none", stroke: "#fff", strokeWidth: 5, strokeLinecap: .round, strokeLinejoin: .round)
  case .ng:
    path("M \(x - 8) \(y - 8) L \(x + 8) \(y + 8) M \(x + 8) \(y - 8) L \(x - 8) \(y + 8)", stroke: "#fff", strokeWidth: 5, strokeLinecap: .round)
  case .warn:
    path("M \(x) \(y - 10) v 11 M \(x) \(y + 9) v 0.5", stroke: "#fff", strokeWidth: 5, strokeLinecap: .round)
  }
}

private func Fan(x: Double, y: Double) {
  g(stroke: "#353b35", strokeWidth: 3, transform: [.translate(x, y)]) {
    circle(r: 26, fill: "#d9dcd8")
    for a in [0.0, 120, 240] {
      path("M 0 0 C 6 -10 18 -18 22 -8 C 14 -4 6 -1 0 0 Z", fill: "#8a9497", transform: [.rotate(a)])
    }
  }
}

private struct Card {
  var text: String
  var kind: Kind
  var icon: () -> Void
}

func Notes(_ props: Props) {
  let n = useNarration()
  let palette = useGuide().palette
  let cards: [Card] = [
    Card(text: "必ず電源を切ってから作業", kind: .ok, icon: { Plug(x: -372, y: 4, cordFrom: Pt(-400, 30)) }),
    Card(text: "高い場所では転倒に注意", kind: .warn, icon: {
      g(stroke: "#353b35", strokeWidth: 4, strokeLinecap: .round) {
        path("M -392 30 L -378 -28 M -352 30 L -366 -28", fill: "none")
        path("M -388 12 H -356 M -384 -8 H -360")
        rect(x: -384, y: -34, width: 28, height: 10, rx: 3, fill: "#c9a77f")
      }
    }),
    Card(text: "モーター・電気部品に水をかけない", kind: .ng, icon: {
      Fan(x: -368, y: 8)
      Icon(name: "water", x: -392, y: -20, size: 34, color: "#4b9cc4", strokeWidth: 2.6)
    }),
    Card(text: "金属フィルターに硬いブラシは使わない", kind: .ng, icon: {
      g(stroke: "#353b35", strokeWidth: 3) {
        rect(x: -396, y: -10, width: 58, height: 18, rx: 5, fill: "#a0785a")
        path("M -392 8 v 16 M -382 8 v 16 M -372 8 v 16 M -362 8 v 16 M -352 8 v 16 M -342 8 v 16", strokeWidth: 4)
      }
    }),
    Card(text: "アルカリ性洗剤は塗装・アルミを傷めることも", kind: .warn, icon: {
      Detergent(x: -368, y: 34, scale: 0.32)
    }),
    Card(text: "機種で外し方・使える洗剤が違う", kind: .ok, icon: {
      Icon(name: "book", x: -368, y: 0, size: 56, color: palette.primary, strokeWidth: 2.4)
    }),
    Card(text: "ファンの分解は説明書の範囲だけ", kind: .warn, icon: {
      Fan(x: -392, y: 4)
      Icon(name: "book", x: -352, y: 14, size: 32, color: palette.primary, strokeWidth: 2.6)
    }),
  ]

  Stage {
    Worker(handR: mix(PRESENTER.restR, PRESENTER.gestureR, n.ease(0, -0.2)))
    for (i, c) in cards.enumerated() {
      let speaking = n.isSpeaking(.index(i))
      Pop(at: n.at(.index(i), 0.1), x: 1190, y: 268 + Double(i) * 87) {
        rect(x: -440, y: -38, width: 880, height: 76, rx: 22, fill: "#fff", stroke: speaking ? palette.primary : palette.ink, strokeWidth: speaking ? 6 : 4, filter: .shadow)
        c.icon()
        Mark(x: -312, y: -18, kind: c.kind, color: palette.primary)
        T(c.text, x: -272, y: 0, size: 30, weight: 900, color: c.kind == .ng ? "#b8402f" : palette.ink, anchor: .start)
      }
    }
  }
}
