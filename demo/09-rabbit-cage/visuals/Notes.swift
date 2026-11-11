// 注意事項: 1 行ごとに注意カード (強い香りの洗剤 NG / すすぐ / うさぎの近くでスプレー NG / トイレは毎日 / 全体は汚れ具合で)
import Foundation
import JGVKit

private func Mark(x: Double, y: Double, ok: Bool = false, color: Paint) {
  g {
    circle(cx: x, cy: y, r: 22, fill: ok ? color : "#d14b3b", stroke: "#353b35", strokeWidth: 3)
    if ok {
      path("M \(x - 10) \(y) l 7 8 l 13 -15", fill: "none", stroke: "#fff", strokeWidth: 5, strokeLinecap: .round, strokeLinejoin: .round)
    } else {
      path("M \(x - 9) \(y - 9) L \(x + 9) \(y + 9) M \(x + 9) \(y - 9) L \(x - 9) \(y + 9)", stroke: "#fff", strokeWidth: 6, strokeLinecap: .round)
    }
  }
}

private struct Card {
  var text: String
  var ng: Bool
  var icon: () -> Void
}

func Notes(_ props: Props) {
  let n = useNarration()
  let palette = useGuide().palette
  let cards: [Card] = [
    Card(text: "強い香りの洗剤は使わない", ng: true, icon: {
      g {
        SprayBottle(x: -300, y: 34, scale: 0.55)
        path("M -278 -30 q 10 -10 0 -20 q -10 -10 0 -20 M -262 -24 q 10 -10 0 -20", fill: "none", stroke: "#e48fb4", strokeWidth: 4, strokeLinecap: .round)
      }
    }),
    Card(text: "洗剤を使ったら十分にすすぐ", ng: false, icon: {
      Icon(name: "water", x: -290, y: 0, size: 64, color: "#4b9cc4", strokeWidth: 2.4)
    }),
    Card(text: "うさぎの近くでスプレーしない", ng: true, icon: {
      g {
        SprayBottle(x: -318, y: 34, scale: 0.5)
        Rabbit(x: -262, y: 36, scale: 0.32)
      }
    }),
    Card(text: "トイレは毎日確認して掃除", ng: false, icon: {
      Toilet(x: -290, y: 30, scale: 0.5)
    }),
    Card(text: "全体の掃除は汚れ具合に応じて", ng: false, icon: {
      g {
        CageBack(x: -290, y: 36, scale: 0.17)
        CageFront(x: -290, y: 36, scale: 0.17)
      }
    }),
  ]
  Stage {
    Presenter(handR: mix(PRESENTER.restR, PRESENTER.gestureR, n.ease(0, -0.2)))
    for (i, c) in cards.enumerated() {
      Pop(at: n.at(.index(i), 0.1), x: 1170, y: 284 + Double(i) * 114) {
        let speaking = n.isSpeaking(.index(i))
        rect(x: -380, y: -48, width: 760, height: 96, rx: 24, fill: "#fff", stroke: speaking ? palette.primary : palette.ink, strokeWidth: speaking ? 6 : 4, filter: .shadow)
        c.icon()
        Mark(x: -228, y: -24, ok: !c.ng, color: palette.primary)
        T(c.text, x: -180, y: 0, size: 34, weight: 900, color: c.ng ? "#b8402f" : palette.ink, anchor: .start)
      }
    }
  }
}
