// この動画専用の道具: 壁掛けエアコン、フィルター、コンセントとプラグ (リモコン・掃除機のノズル・蛇口などは kit の Household.swift)
import JGVKit

private let DUST: Paint = "#9b958a"

// ---------- 壁掛けエアコン (原点 = 本体上辺の中心) ----------
// on: 運転 (0〜1)、panel: 前面パネルを開く (0〜1)、filterOut: 左のフィルターを引き出す (0〜1)、dust: ホコリ (0〜1)
let AIRCON_PARTS = Parts([
  "panelL": Pt(-250, 128),
  "panelR": Pt(250, 128),
  "filterHandle": Pt(-130, 146),
  "cord": Pt(280, 120),
  "front": Pt(0, 170),
])
func AirCon(x: Double, y: Double, scale: Double = 1, angle: Double = 0, on: Double = 0, panel: Double = 0, filterOut: Double = 0, dust: Double = 0, hideFilter: Bool = false) {
  let frame = useCurrentFrame()
  let fps = useVideoConfig().fps
  let palette = useGuide().palette
  let t = frame / fps
  let h = 130 - 236 * panel // パネル下端 (開くと上辺より上へ)
  let w = 280 + 28 * panel
  Placed(x: x, y: y, scale: scale, angle: angle) {
    // 吹き出す風
    if on > 0.02 {
      for i in 0 ..< 3 {
        let fi = Double(i)
        let k = jsMod(t * 0.8 + fi / 3, 1)
        path("M \(-200 + fi * 160) \(190 + k * 120) q 30 20 0 40 q -30 20 0 40", fill: "none", stroke: "#8ab8c8", strokeWidth: 6,
             opacity: on * sin(k * Double.pi) * 0.9)
      }
    }
    rect(x: -280, y: 0, width: 560, height: 170, rx: 26, fill: "#f7f5ef")
    // 内部とフィルター (パネルを開くと見える)
    rect(x: -262, y: 18, width: 524, height: 126, rx: 10, fill: "#d9dedc", strokeWidth: 4)
    for (i, fx) in [-130.0, 130.0].enumerated() {
      if !(hideFilter && i == 0) {
        g(opacity: i == 0 ? 1 - max(0, filterOut - 0.8) * 5 : 1, transform: [.translate(0, i == 0 ? filterOut * 260 : 0)]) {
          Filter(x: fx, y: 81, scale: 0.36, dust: dust)
        }
      }
    }
    // ルーバー
    path("M -240 \(150) L 240 \(150) L 230 \(150 + 18 + 22 * on) L -230 \(150 + 18 + 22 * on) Z", fill: "#e6e3da", strokeWidth: 4)
    circle(cx: 232, cy: 136, r: 7, fill: on > 0.5 ? "#4cc27a" : "#b5b0a5", strokeWidth: 3)
    // 前面パネル
    path("M -280 4 L 280 4 L \(w) \(h) L \(-w) \(h) Z", fill: "#fbfaf6", opacity: panel > 0.45 && panel < 0.55 ? 0.9 : 1)
    if panel < 0.4 { path("M -200 \(h * 0.5) H 200", stroke: "#e1ddd2", strokeWidth: 4) }
    path("M -\(w - 30) \(h - (h > 0 ? 10 : -10)) H \(w - 30)", stroke: palette.ink, strokeWidth: 3, opacity: 0.25)
  }
}

// ---------- フィルター (原点 = 中心、幅 320 × 高さ 220) ----------
// dust: ホコリ (数値 or 3 段それぞれの量)、wet: 濡れ (0〜1)、flip: 裏返す (0〜1)、bend: 曲げる (0〜1)
let FILTER_PARTS = Parts(["handle": Pt(0, 122), "left": Pt(-160, 0), "right": Pt(160, 0)])
func Filter(x: Double, y: Double, scale: Double = 1, angle: Double = 0, dust: Double = 0, wet: Double = 0, flip: Double = 0, bend: Double = 0, label: Bool = false) {
  Filter(x: x, y: y, scale: scale, angle: angle, dust: [dust, dust, dust], wet: wet, flip: flip, bend: bend, label: label)
}
func Filter(x: Double, y: Double, scale: Double = 1, angle: Double = 0, dust rows: [Double], wet: Double = 0, flip: Double = 0, bend: Double = 0, label: Bool = false) {
  let sx = cos(flip * Double.pi)
  let back = flip > 0.5
  let b = bend * 60
  let outline = "M -160 -110 Q 0 \(-110 + b) 160 -110 L 160 110 Q 0 \(110 + b) -160 110 Z"
  Placed(x: x, y: y, scale: scale, angle: angle) {
    g(transform: [.scale(max(0.04, abs(sx)), 1)]) {
      path(outline, fill: "#e3e9ea")
      // 網目
      g(stroke: "#a9b6b9", strokeWidth: 2.5) {
        for i in 0 ..< 11 {
          let fi = Double(i)
          let sag = b * (1 - pow((fi - 5) / 5, 2))
          line(x1: -130 + fi * 26, y1: -96 + sag, x2: -130 + fi * 26, y2: 96 + sag)
        }
        for i in 0 ..< 7 {
          let yy = -84 + Double(i) * 28
          path("M -146 \(yy) Q 0 \(yy + b) 146 \(yy)", fill: "none")
        }
      }
      // ホコリ (3 段)
      for (row, r) in rows.enumerated() where r > 0.01 {
        g(stroke: "none", opacity: r) {
          for i in 0 ..< 14 {
            let ex = -140 + random("dx\(row)\(i)") * 280
            let ey = -100 + Double(row) * 70 + random("dy\(row)\(i)") * 60
            ellipse(cx: ex, cy: ey + b * 0.6, rx: 14 + random("dr\(row)\(i)") * 18, ry: 8 + random("ds\(row)\(i)") * 8, fill: DUST, opacity: 0.75)
          }
        }
      }
      if wet > 0.01 { path(outline, fill: "#6fb6d6", stroke: "none", opacity: 0.25 * wet) }
      path(outline, fill: "none", stroke: "#7d8d91", strokeWidth: 10)
      path(outline, fill: "none")
      rect(x: -30, y: 108 + b, width: 60, height: 26, rx: 8, fill: "#7d8d91")
      if label {
        g(transform: [.scale(sx < 0 ? -1 : 1, 1)]) {
          circle(cx: -120, cy: -72, r: 26, fill: "#fff", strokeWidth: 4)
          text(back ? "裏" : "表", x: -120, y: -72, fontSize: 30, fontWeight: 900, fontFamily: "\"Hiragino Sans\", sans-serif", fill: "#353b35", stroke: "none",
               textAnchor: .middle, dominantBaseline: .central)
        }
      }
    }
  }
}

// ---------- コンセントとプラグ ----------
func Outlet(x: Double, y: Double) {
  Placed(x: x, y: y) {
    rect(x: -38, y: -52, width: 76, height: 104, rx: 12, fill: "#f7f5ef")
    path("M -10 -22 v 18 M 10 -22 v 18", strokeWidth: 5)
  }
}
/// プラグ (原点 = 刃の付け根、刃は上向き)。cordTo へコードを伸ばす
func Plug(x: Double, y: Double, angle: Double = 0, cordFrom: Pt) {
  let palette = useGuide().palette
  let cord = "M \(cordFrom.x) \(cordFrom.y) C \(cordFrom.x + 40) \(cordFrom.y + 120) \(x + 60) \(y - 80) \(x) \(y + 40)"
  g {
    path(cord, fill: "none", stroke: palette.ink, strokeWidth: 10, strokeLinecap: .round)
    path(cord, fill: "none", stroke: "#e8e4da", strokeWidth: 4, strokeLinecap: .round)
    Placed(x: x, y: y, angle: angle) {
      path("M -10 -14 v -16 M 10 -14 v -16", stroke: "#b9b4a8", strokeWidth: 6)
      rect(x: -24, y: -14, width: 48, height: 52, rx: 10, fill: "#e9e5db")
    }
  }
}
