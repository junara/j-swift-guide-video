// はじめに: 運転中のエアコンにホコリが舞い、効率メーターが下がる → 掃除方法の案内
import JGVKit

func Intro(_ props: Props) {
  let n = useNarration()
  let palette = useGuide().palette
  let dust = interpolate(n.frame, [n.atPhrase(0, 0), n.atPhrase(0, 1)], [0, 1], .clamp) * (1 - n.ease(1, 0.3))
  let drop = interpolate(n.frame, [n.atPhrase(0, 1, 0.2), n.endOf(0)], [0, 1], .clamp)
  let gx = 1580.0, gy = 330.0, gr = 100.0
  let angle = 330 - drop * 110 // 330°(高い) → 220°(低い)
  let gaugeOn = interpolate(n.frame, [n.atPhrase(0, 1, -0.2), n.atPhrase(0, 1, 0.2)], [0, 1], .clamp) * (1 - n.ease(1))
  Stage {
    Outlet(x: OUTLET.x, y: OUTLET.y)
    Plug(x: PLUG_IN.x, y: PLUG_IN.y, cordFrom: CORD_FROM)
    AirCon(x: AC.x, y: AC.y, on: 1)
    // 舞うホコリ
    g(opacity: dust) {
      for i in 0 ..< 26 {
        let fi = Double(i)
        let x = AC.x - 300 + random("ix\(i)") * 600 + sin(n.sec * 1.3 + fi) * 14
        let y = AC.y + 190 + jsMod(random("iy\(i)") * 260 + n.sec * 30, 260)
        circle(cx: x, cy: y, r: 4 + random("ir\(i)") * 6, fill: "#9b958a", opacity: 0.7)
      }
    }
    // 効率メーター
    g(opacity: gaugeOn) {
      Draw(d: arcPath(gx, gy, gr, 180, 360), progress: 1, color: "#e3dccb", width: 22)
      Draw(d: arcPath(gx, gy, gr, 180, 240), progress: 1, color: "#d14b3b", width: 22)
      let rad = angle * Double.pi / 180
      line(x1: gx, y1: gy, x2: gx + cos(rad) * (gr - 20), y2: gy + sin(rad) * (gr - 20), stroke: palette.ink, strokeWidth: 8, strokeLinecap: .round)
      circle(cx: gx, cy: gy, r: 12, fill: palette.ink)
      T("冷暖房の効率", x: gx, y: gy + 50, size: 30, weight: 900, color: drop > 0.6 ? "#d14b3b" : palette.ink)
    }
    Presenter(handR: mix(PRESENTER.restR, PRESENTER.gestureR, n.ease(0, 0)))
    Burst(at: n.at(1, 0.4), x: AC.x, y: AC.y + 85, r: 260, count: 16, color: palette.accent)
    Callout(x: AC.x, y: GUIDE.counterY - 200, text: "自宅で簡単にできるフィルター掃除", at: n.at(1, 0.4))
  }
}
