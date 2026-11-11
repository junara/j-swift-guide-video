import Foundation
import JGVKit

let PH = phoneSpace(x: 560, y: 226, h: 652)
private let ICON = Pt(150, 150), TAB = Pt(195, 800), PLUS = Pt(352, 75), HOURC = Pt(140, 320), MINC = Pt(250, 320), SAVE = Pt(195, 772), TOG = Pt(330, 186)
private let SPOTS: [String: Box] = ["tab": Box(x: 140, y: 776, w: 110, h: 52), "plus": Box(x: 322, y: 52, w: 60, h: 48),
  "wheels": Box(x: 70, y: 220, w: 250, h: 200), "save": Box(x: 24, y: 744, w: 342, h: 56), "toggle": Box(x: 290, y: 162, w: 80, h: 48)]

private func Toggle(_ x: Double, _ y: Double, _ on: Double) {
  let palette = useGuide().palette
  rect(x: x - 26, y: y - 15, width: 52, height: 30, rx: 15, fill: Paint("#d6d6d0").mix(palette.primary, on))
  circle(cx: x - 11 + 22 * on, cy: y, r: 12, fill: "#ffffff", stroke: "#c9c9c3", strokeWidth: 2)
}
private func TabBar(_ alarm: Bool) {
  let palette = useGuide().palette
  rect(y: 768, width: 390, height: 76, fill: "#f7f6f2")
  for (i, t) in ["世界時計", "アラーム", "タイマー"].enumerated() {
    UIText(t, x: 65 + 130 * Double(i), y: 812, size: 15, color: (i == 1) == alarm ? palette.primary : "#9a9d97", anchor: .middle)
  }
}
private func Wheel(_ x: Double, _ v: Double, _ mod: Double, _ pad: Bool) {
  let base = v.rounded(.down), frac = v - base
  for k in -2 ... 2 {
    let n = Int((base + Double(k)).truncatingRemainder(dividingBy: mod) + mod) % Int(mod)
    let y = 320 + (Double(k) - frac) * 56
    let near = max(0, 1 - abs(y - 320) / 120)
    UIText(pad ? String(format: "%02d", n) : String(n), x: x, y: y + 14, size: 26 + 16 * near, weight: 700, color: Paint("#b9bcb5").mix("#2b302d", near), anchor: .middle, mono: true)
  }
}

/// アラームアプリの画面 (設計座標)
private func AlarmScreen(_ s: CueState) {
  let palette = useGuide().palette
  switch s.s("page") {
  case "home", "":
    rect(width: 390, height: 844, fill: .linear(LinearGradient(x1: 0, y1: 0, x2: 0, y2: 1, stops: [(0, Paint("#cfe3d6")), (1, Paint("#f3e6cf"))])))
    let colors: [Paint] = ["#e8a87c", "#ffffff", "#8fc1d4", "#c3a6d8", "#f2c14e", "#9fd3a8", "#e57373", "#7fa7d9"]
    for i in 0 ..< 12 {
      let c = Pt(60 + 90 * Double(i % 4), 150 + 110 * Double(i / 4))
      let isClock = i == 1
      rect(x: c.x - 30, y: c.y - 30, width: 60, height: 60, rx: 15, fill: isClock ? palette.ink : colors[i % 8], stroke: "#ffffff", strokeWidth: 2)
      if isClock {
        circle(cx: c.x, cy: c.y, r: 20, fill: "#ffffff")
        path("M \(c.x) \(c.y) V \(c.y - 13) M \(c.x) \(c.y) L \(c.x + 9) \(c.y + 5)", stroke: palette.ink, strokeWidth: 3)
      }
      UIText(isClock ? "時計" : "", x: c.x, y: c.y + 52, size: 14, color: "#2b302d", anchor: .middle)
    }
    let o = s["appOpen"]
    if o > 0.01 {
      let w = 60 + 330 * o, h = 60 + 784 * o
      rect(x: ICON.x - 30 + (0 - (ICON.x - 30)) * o, y: ICON.y - 30 + (0 - (ICON.y - 30)) * o, width: w, height: h, rx: 15 * (1 - o), fill: "#ffffff", opacity: min(1, o * 2))
    }
  case "clock":
    rect(width: 390, height: 844, fill: "#ffffff")
    UIAppBar(title: "世界時計", width: 390)
    for (i, c) in [("東京", "9:41"), ("ロンドン", "1:41"), ("ニューヨーク", "20:41")].enumerated() {
      UIListRow(x: 0, y: 100 + 72 * Double(i), w: 390, title: c.0, right: c.1)
    }
    TabBar(false)
  case "list":
    rect(width: 390, height: 844, fill: "#ffffff")
    UIAppBar(title: "アラーム", width: 390)
    UIText("＋", x: PLUS.x, y: PLUS.y + 10, size: 30, weight: 700, color: "#ffffff", anchor: .middle)
    let nr = s["newRow"]
    if nr > 0.01 {
      g(opacity: nr) {
        UIListRow(x: 0, y: 150, w: 390, title: "7:00", sub: "アラーム", highlight: 1 - nr)
        Toggle(TOG.x, TOG.y, s["toggle"])
      }
    }
    UIListRow(x: 0, y: 150 + 72 * nr, w: 390, title: "6:30", sub: "平日")
    Toggle(TOG.x, TOG.y + 72 * nr, 0)
    TabBar(true)
  default: // edit
    rect(width: 390, height: 844, fill: "#ffffff")
    UIAppBar(title: "アラームを追加", width: 390)
    rect(x: 30, y: 292, width: 330, height: 56, rx: 12, fill: palette.primary, opacity: 0.1)
    Wheel(HOURC.x, s["hour"], 24, false)
    UIText(":", x: 195, y: 334, size: 40, weight: 700, color: "#2b302d", anchor: .middle)
    Wheel(MINC.x, s["min"], 60, true)
    UIListRow(x: 0, y: 470, w: 390, title: "繰り返し", right: "しない")
    UIButton(x: 24, y: 744, w: 342, h: 56, label: "保存", pressed: s.s("pressed") == "save")
  }
}

let ALARM_BIND = CueBinding(
  keys: ["page", "appOpen", "hour", "min", "newRow", "toggle", "spot", "spot.o"],
  points: [
    "rest": { _ in PH.pt(Pt(330, 690)) }, "notes": { _ in Pt(1000, 270) },
    "clock": { _ in PH.pt(ICON) }, "tab": { _ in PH.pt(TAB) }, "plus": { _ in PH.pt(PLUS) },
    "hour": { _ in PH.pt(HOURC) }, "min": { _ in PH.pt(MINC) }, "save": { _ in PH.pt(SAVE) },
    "toggle": { _ in PH.pt(TOG) }, "badge": { _ in PH.pt(Pt(TOG.x - 90, TOG.y)) },
  ],
  hand: .finger,
  draw: { s in PhoneFrame(x: PH.x, y: PH.y, h: PH.h) { AlarmScreen(s) } },
  front: { s in if let b = SPOTS[s.s("spot")], s["spot.o"] > 0.01 { Spotlight(rect: PH.rect(b), opacity: s["spot.o"], area: PH.box) } }
)
