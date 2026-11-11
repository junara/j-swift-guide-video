// この動画専用の道具: 換気扇フード、フィルター、きらめき (掃除道具・コンロ・シンクと蛇口などは kit の Household.swift)
import JGVKit

private let OIL: Paint = "#b07a2e"
private let GRIME: Paint = "#7d531c"
private let METAL: Paint = "#c9d1d3"
private let MESH: Paint = "#9aa6a9"

/// 油汚れの量: 数値 (全体) か 左・中・右の 3 区画それぞれの量
struct Oil: ExpressibleByFloatLiteral, ExpressibleByIntegerLiteral, ExpressibleByArrayLiteral {
  var regions: [Double]
  init(_ v: Double) { regions = [v, v, v] }
  init(_ r: [Double]) { regions = r }
  init(floatLiteral value: Double) { self.init(value) }
  init(integerLiteral value: Int) { self.init(Double(value)) }
  init(arrayLiteral elements: Double...) { self.init(elements) }
}

// ---------- フィルターの面 (中心が原点、幅 w × 高さ h でそのまま描く) ----------
// oil: 油汚れ (数値 or 左・中・右の 3 区画それぞれの量)、gaps: 網目の隙間の汚れ、foam: 泡、wet: 濡れ
func FilterFace(w: Double, h: Double, oil: Oil = 0, gaps: Double = 0, foam: Double = 0, wet: Double = 0, seed: String = "f") {
  let regions = oil.regions
  let k = h / 240 // 縦の縮み (寝かせたときは小さい)
  let inset = 14.0
  let iw = w - inset * 2
  let ih = h - inset * 2 * max(0.4, k)
  let cols = jsRound(iw / 20)
  let rows = max(2, jsRound(6 * k + 1))
  let corner = min(12, h / 4)
  rect(x: -w / 2, y: -h / 2, width: w, height: h, rx: corner, fill: METAL)
  // 網目
  g(stroke: MESH, strokeWidth: 2.5) {
    for i in 0..<max(0, Int(cols) - 1) {
      let x = -iw / 2 + (Double(i + 1) * iw) / cols
      line(x1: x, y1: -ih / 2, x2: x, y2: ih / 2)
    }
    for i in 0..<max(0, Int(rows) - 1) {
      let y = -ih / 2 + (Double(i + 1) * ih) / rows
      line(x1: -iw / 2, y1: y, x2: iw / 2, y2: y)
    }
  }
  rect(x: -iw / 2, y: -ih / 2, width: iw, height: ih, rx: 4, fill: "none", stroke: MESH, strokeWidth: 3)
  // 隙間にこびりついた汚れ
  if gaps > 0.01 {
    g(stroke: GRIME, strokeWidth: 4.5, opacity: gaps) {
      for i in 0..<12 {
        let c = floor(random("\(seed)gc\(i)") * (cols - 1))
        let x = -iw / 2 + ((c + 1) * iw) / cols
        let y0 = -ih / 2 + random("\(seed)gy\(i)") * ih * 0.7
        line(x1: x, y1: y0, x2: x, y2: y0 + ih * 0.22)
      }
    }
  }
  // 油汚れ (3 区画)
  for (reg, r) in regions.enumerated() where r > 0.01 {
    g(stroke: "none", opacity: r) {
      for i in 0..<6 {
        let x = -iw / 2 + (Double(reg) * iw) / 3 + random("\(seed)ox\(reg)\(i)") * (iw / 3)
        let y = -ih / 2 + random("\(seed)oy\(reg)\(i)") * ih
        let rx = (w / 360) * (16 + random("\(seed)or\(reg)\(i)") * 22)
        ellipse(cx: x, cy: y, rx: rx, ry: rx * max(0.3, k) * 0.7, fill: OIL, opacity: 0.7)
      }
    }
  }
  if wet > 0.01 {
    rect(x: -w / 2, y: -h / 2, width: w, height: h, rx: corner, fill: "#6fb6d6", stroke: "none", opacity: 0.28 * wet)
  }
  if foam > 0.01 {
    g(fill: "#ffffff", stroke: "#b9c6cc", strokeWidth: 2, opacity: foam) {
      for i in 0..<22 {
        let x = (random("\(seed)fx\(i)") - 0.5) * iw
        let y = (random("\(seed)fy\(i)") - 0.5) * ih
        circle(cx: x, cy: y, r: (w / 360) * (8 + random("\(seed)fr\(i)") * 12))
      }
    }
  }
  rect(x: -w / 2, y: -h / 2, width: w, height: h, rx: corner, fill: "none")
}

// ---------- フィルター単体 (原点 = 中心)。flat: 寝かせて置いた見え方 (0〜1) ----------
let FILTER_W: Double = 360
func filterH(_ flat: Double) -> Double { 240 - 168 * flat }
let FILTER_PARTS = Parts(["holdL": Pt(-180, 0), "holdR": Pt(180, 0), "top": Pt(0, -120)])
func HoodFilter(
  x: Double, y: Double, scale: Double = 1, angle: Double = 0,
  flat: Double = 0, oil: Oil = 0, gaps: Double = 0, foam: Double = 0, wet: Double = 0, seed: String = "f"
) {
  Placed(x: x, y: y, scale: scale, angle: angle) {
    FilterFace(w: FILTER_W, h: filterH(flat), oil: oil, gaps: gaps, foam: foam, wet: wet, seed: seed)
  }
}

// ---------- 換気扇フード (原点 = フード下面の中心) ----------
// on: 運転 (ランプ)、spin: 羽根の角度 (度)、knob: つまみを回す (0〜1)、drop: フィルターを下ろす量 (px)、hideFilter: フィルターなし
// dirt: 本体の油汚れ、soap: 洗剤の拭き跡、oil / gaps: フィルターの汚れ
let HOOD_PARTS = Parts([
  "knobL": Pt(-258, -40),
  "knobR": Pt(258, -40),
  "filterL": Pt(-220, -40),
  "filterR": Pt(220, -40),
  "filter": Pt(0, -40),
  "button": Pt(218, -110),
  "cord": Pt(310, -116),
  "canopy": Pt(0, -186),
])
let HOOD_FILTER = (w: 520.0, h: 62.0)
func RangeHood(
  x: Double, y: Double, scale: Double = 1, angle: Double = 0,
  on: Double = 0, spin: Double = 0, knob: Double = 0, drop: Double = 0, hideFilter: Bool = false,
  dirt: Double = 0, soap: Double = 0, oil: Oil = 0, gaps: Double = 0
) {
  let palette = useGuide().palette
  Placed(x: x, y: y, scale: scale, angle: angle) {
    // ダクトカバー
    rect(x: -82, y: -640, width: 164, height: 410, fill: "#e2e0d9")
    path("M -50 -640 V -232", stroke: "#cfcbc1", strokeWidth: 4)
    // フード
    path("M -164 -232 L 164 -232 L 312 -142 L -312 -142 Z", fill: "#eeece6")
    rect(x: -312, y: -144, width: 624, height: 66, rx: 10, fill: "#f7f6f1")
    rect(x: 186, y: -128, width: 100, height: 36, rx: 10, fill: "#d9dcd8", strokeWidth: 4)
    circle(cx: HOOD_PARTS.button.x, cy: HOOD_PARTS.button.y, r: 10, fill: palette.accent, strokeWidth: 3)
    circle(cx: 262, cy: -110, r: 8, fill: on > 0.5 ? "#4cc27a" : "#b5b0a5", strokeWidth: 3)
    // 本体の油汚れ・拭き跡
    if dirt > 0.01 {
      g(stroke: "none", opacity: dirt) {
        for i in 0..<16 {
          let t = random("hd\(i)")
          let y = -225 + random("hdy\(i)") * 140
          let half = y < -142 ? 164 + ((y + 232) / 90) * 148 : 300
          ellipse(cx: (t - 0.5) * 2 * (half - 30), cy: y, rx: 12 + random("hdr\(i)") * 18, ry: 6 + random("hds\(i)") * 6, fill: OIL, opacity: 0.6)
        }
        for (i, x) in [-240.0, -90, 60, 200].enumerated() {
          path("M \(x) -80 q -4 14 0 \(16 + i * 4) q 4 6 0 8", fill: OIL, opacity: 0.7)
        }
      }
    }
    if soap > 0.01 {
      g(fill: "none", stroke: "#ffffff", strokeWidth: 10, opacity: soap * 0.75) {
        path("M -230 -170 q 60 -20 120 0 t 120 0 t 120 0 t 110 0")
        path("M -280 -112 q 70 -16 140 0 t 140 0 t 140 0 t 120 0")
      }
    }
    // 内部 (羽根)
    rect(x: -292, y: -80, width: 584, height: 80, rx: 6, fill: "#4b5356")
    g(transform: [.translate(0, -40), .scale(1, 0.42)]) {
      circle(r: 74, fill: "#5f686b", strokeWidth: 4)
      g(transform: [.rotate(spin)]) {
        for a in [0.0, 90, 180, 270] {
          path("M 0 0 C 20 -24 60 -40 68 -14 C 50 -6 24 0 0 0 Z", fill: "#aab4b6", strokeWidth: 3, transform: [.rotate(a)])
        }
      }
      circle(r: 14, fill: "#353b35", stroke: "none")
    }
    // フィルター
    if !hideFilter {
      g(opacity: 0.78, transform: [.translate(0, -40 + drop)]) {
        FilterFace(w: HOOD_FILTER.w, h: HOOD_FILTER.h, oil: oil, gaps: gaps, seed: "hf")
      }
    }
    // つまみ
    for s in [-1.0, 1] {
      g(transform: [.translate(s * 258, -40), .rotate(knob * 90 * s)]) {
        rect(x: -9, y: -20, width: 18, height: 40, rx: 6, fill: "#7d8a8e", strokeWidth: 4)
      }
    }
  }
}

// ---------- きらめき ----------
/// きらめき (範囲内に count 個が明滅)
func Sparkles(x: Double, y: Double, w: Double, h: Double, on: Double = 1, count: Int = 6, seed: String = "sp") {
  let frame = useCurrentFrame()
  if on <= 0.01 { return }
  g(opacity: on) {
    for i in 0..<count {
      let k = jsMod(frame * 0.04 + random("\(seed)\(i)"), 1)
      let s = sin(k * Double.pi) * 16
      let cx = x + (random("\(seed)x\(i)") - 0.5) * w
      let cy = y + (random("\(seed)y\(i)") - 0.5) * h
      path("M \(cx) \(cy - s) Q \(cx) \(cy) \(cx + s) \(cy) Q \(cx) \(cy) \(cx) \(cy + s) Q \(cx) \(cy) \(cx - s) \(cy) Q \(cx) \(cy) \(cx) \(cy - s) Z",
           fill: "#fff6c8", stroke: "#e0b84a", strokeWidth: 2)
    }
  }
}
