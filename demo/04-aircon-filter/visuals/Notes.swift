// 注意事項: 1 行ごとに注意カード (濡れたまま取り付けない / 熱湯・硬いブラシ NG / 取扱説明書を確認)
import JGVKit

private func Ng(x: Double, y: Double) {
  g {
    circle(cx: x, cy: y, r: 24, fill: "#d14b3b", stroke: "#353b35", strokeWidth: 3)
    path("M \(x - 10) \(y - 10) L \(x + 10) \(y + 10) M \(x + 10) \(y - 10) L \(x - 10) \(y + 10)", stroke: "#fff", strokeWidth: 6, strokeLinecap: .round)
  }
}

func Notes(_ props: Props) {
  let n = useNarration()
  let palette = useGuide().palette
  let cards: [(y: Double, text: String)] = [
    (520, "濡れたまま取り付けない"),
    (640, "熱湯・硬いブラシは使わない"),
    (760, "取扱説明書を必ず確認"),
  ]
  Stage {
    Outlet(x: OUTLET.x, y: OUTLET.y)
    Plug(x: PLUG_IN.x, y: PLUG_IN.y, cordFrom: CORD_FROM)
    AirCon(x: AC.x, y: AC.y, on: 1)
    Presenter(handR: mix(PRESENTER.restR, PRESENTER.gestureR, n.ease(0, -0.2)))
    for (i, c) in cards.enumerated() {
      Pop(at: n.at(.index(i), 0.1), x: 1080, y: c.y - 20) {
        rect(x: -330, y: -48, width: 660, height: 96, rx: 24, fill: "#fff", stroke: palette.ink, strokeWidth: 4, filter: .shadow)
        if i == 0 {
          g {
            Filter(x: -260, y: 0, scale: 0.26, wet: 1)
            Ng(x: -212, y: -24)
          }
        } else if i == 1 {
          g {
            path("M -300 10 q 10 -24 0 -40 M -276 10 q 10 -24 0 -40", fill: "none", stroke: "#d98a5c", strokeWidth: 5, strokeLinecap: .round)
            rect(x: -250, y: -6, width: 44, height: 22, rx: 6, fill: "#c9a77f", stroke: "#353b35", strokeWidth: 3)
            path("M -246 16 v 18 M -236 16 v 18 M -226 16 v 18 M -216 16 v 18", stroke: "#353b35", strokeWidth: 3)
            Ng(x: -200, y: -26)
          }
        } else {
          g {
            Icon(name: "book", x: -262, y: 0, size: 70, color: palette.primary, strokeWidth: 2.4)
            circle(cx: -212, cy: -24, r: 24, fill: palette.primary, stroke: "#353b35", strokeWidth: 3)
            path("M -223 -24 l 7 8 l 14 -15", fill: "none", stroke: "#fff", strokeWidth: 5, strokeLinecap: .round, strokeLinejoin: .round)
          }
        }
        T(c.text, x: -160, y: 0, size: 34, weight: 900, color: i < 2 ? "#b8402f" : palette.ink, anchor: .start)
      }
    }
  }
}
