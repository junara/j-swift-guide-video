// はじめに: 料理の湯気を吸う換気扇に油汚れがたまる → 換気効率が下がり、臭いが出る → 定期的な掃除で防ぐ → フィルターを中心に説明
import JGVKit

func Intro(_ props: Props) {
  let n = useNarration()
  let palette = useGuide().palette
  let grime = interpolate(n.frame, [n.atPhrase(0, 1), n.endOf(0)], [0, 1], .clamp)
  let spin = spinAngle(n.frame) { _ in 16 }
  // 2 行目: 効率メーターが下がる → 臭い → 掃除で防ぐ
  let gm = (x: 1600.0, y: 330.0, r: 92.0)
  let drop = interpolate(n.frame, [n.atPhrase(1, 1, 0.1), n.atPhrase(1, 2)], [0, 1], .clamp)
  let angle = 330 - drop * 110
  let panel = interpolate(n.frame, [n.atPhrase(1, 1, -0.2), n.atPhrase(1, 1, 0.2)], [0, 1], .clamp) * (1 - n.ease(2, -0.1))
  let smell = interpolate(n.frame, [n.atPhrase(1, 2, -0.1), n.atPhrase(1, 2, 0.3)], [0, 1], .clamp) * (1 - n.ease(2, -0.1))
  let protect = n.atPhrase(1, 2, 0.9)
  let needle = Pt(gm.x + cos((angle * Double.pi) / 180) * (gm.r - 22), gm.y + sin((angle * Double.pi) / 180) * (gm.r - 22))

  Stage {
    Outlet(x: OUTLET.x, y: OUTLET.y)
    Plug(x: PLUG_IN.x, y: PLUG_IN.y, cordFrom: CORD_FROM)
    Suction(x: COOK.x - 110, y: HOOD.y + 10, from: 150, on: 1, color: "#b8c3c4")
    RangeHood(x: HOOD.x, y: HOOD.y, on: 1, spin: spin, dirt: grime * 0.9, oil: Oil(grime), gaps: grime * 0.8)
    Cooktop(x: COOK.x, y: COOK.y, pot: true, flame: 1)
    // 換気効率メーター
    g(opacity: panel) {
      circle(cx: gm.x, cy: gm.y + 10, r: gm.r + 44, fill: "#fff", stroke: palette.ink, strokeWidth: 4, opacity: 0.92)
      Draw(d: arcPath(gm.x, gm.y, gm.r, 180, 360), progress: 1, color: "#e3dccb", width: 22)
      Draw(d: arcPath(gm.x, gm.y, gm.r, 180, 240), progress: 1, color: "#d14b3b", width: 22)
      line(x1: gm.x, y1: gm.y, x2: needle.x, y2: needle.y, stroke: palette.ink, strokeWidth: 8, strokeLinecap: .round)
      circle(cx: gm.x, cy: gm.y, r: 12, fill: palette.ink)
      T("換気効率", x: gm.x, y: gm.y + 52, size: 28, weight: 900, color: drop > 0.6 ? "#d14b3b" : palette.ink)
    }
    // 嫌な臭い
    g(fill: "none", stroke: "#9aa858", strokeWidth: 7, strokeLinecap: .round, opacity: smell) {
      for i in 0..<3 {
        let k = jsMod(n.sec * 0.6 + Double(i) / 3, 1)
        let x = 1520 + Double(i) * 70
        path("M \(x) \(640 - k * 120) q 18 -18 0 -36 q -18 -18 0 -36 q 18 -18 0 -36", opacity: sin(k * Double.pi))
      }
      T("嫌な臭い", x: 1590, y: 680, size: 28, weight: 900, color: "#7a8640")
    }
    Pop(at: protect, x: 1600, y: 480) {
      circle(r: 86, fill: "#fff", stroke: palette.primary, strokeWidth: 6)
      Icon(name: "shield", x: 0, y: -8, size: 110, progress: interpolate(n.frame, [protect, protect + 15], [0, 1], .clamp), color: palette.primary, strokeWidth: 2.4)
      T("定期的な掃除で防ぐ", x: 0, y: 112, size: 28, weight: 900, color: palette.primary)
    }
    // 3 行目: フィルターを中心に
    Pulse(x: HOOD.x, y: HOOD.y - 40, r: 300, color: palette.accent, period: 1.6, active: n.isSpeaking(2))
    Burst(at: n.atPhrase(2, 1, 0.1), x: HOOD.x, y: HOOD.y - 40, r: 320, count: 16, color: palette.accent)
    Callout(x: HOOD.x, y: HOOD.y + 70, text: "フィルターを中心に掃除", at: n.atPhrase(2, 1, 0.1))
    Callout(x: 1600, y: 660, text: "家庭でできる掃除方法", at: n.atPhrase(2, 2))
    Worker(handR: mix(PRESENTER.restR, PRESENTER.gestureR, n.ease(0, 0.2)))
  }
}
