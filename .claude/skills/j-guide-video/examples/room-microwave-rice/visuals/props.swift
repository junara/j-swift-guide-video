// この動画で描き足した道具: 冷凍ごはん (ラップ付き)・お皿・お茶わん (原点 = 底の中心、輪郭線は ink)。電子レンジは assets/microwave.svg
import JGVKit

// ---------- 冷凍ごはん (幅 150 × 高さ 46) ----------

/// 冷凍ごはんの持つ所 (ローカル座標): grip = 上の面の中央、top = ラップの結び目 (はがし始める所)
let RICE_PARTS = Parts(["grip": Pt(0, -46), "top": Pt(52, -44)])

/// ラップに包んだ平たいごはん。heat: 0 凍っている (白く霜がかった色) 〜 1 温まった、wrap: ラップ (1 包んだまま〜0 外した)、
/// loose: ほぐれ具合 (0 四角い塊〜1 ふんわりした山)、amount: 残りの量 (1 全部〜0 なし。お茶わんに盛った分だけ減る)
func FrozenRice(x: Double, y: Double, scale: Double = 1, angle: Double = 0, heat: Double, wrap: Double, loose: Double = 0, amount: Double = 1) {
  let h = min(1, max(0, heat))
  let l = min(1, max(0, loose))
  let a = min(1, max(0, amount))
  let rice = Paint("#e4ecef").mix("#fbf7ee", h)
  Placed(x: x, y: y, scale: scale, angle: angle) {
    if a > 0.02 {
      // 四角い塊 (ほぐすと消えていく)
      if l < 0.98 {
        g(opacity: 1 - l) {
          rect(x: -72 * a, y: -44 * a, width: 144 * a, height: 44 * a, rx: 14 * a, fill: rice)
          for (i, gx) in [-44.0, -14, 18, 46].enumerated() where gx * a > -66 {
            ellipse(cx: gx * a, cy: (-26 + Double(i % 2) * 10) * a, rx: 7 * a, ry: 4 * a, fill: "#ffffff", strokeWidth: 2)
          }
        }
      }
      // ほぐした山
      if l > 0.02 {
        g(opacity: l) {
          path("M \(-78 * a) 0 C \(-70 * a) \(-40 * a) \(-30 * a) \(-58 * a) 0 \(-58 * a) C \(30 * a) \(-58 * a) \(70 * a) \(-40 * a) \(78 * a) 0 Z", fill: rice)
          for gx in [-40.0, -12, 16, 42] { ellipse(cx: gx * a, cy: -22 * a - abs(gx) * 0.1, rx: 7 * a, ry: 4 * a, fill: "#ffffff", strokeWidth: 2) }
        }
      }
      // 霜 (凍っているときだけ)
      if h < 0.6 {
        path("M \(-50 * a) \(-36 * a) l 12 0 M \(-44 * a) \(-42 * a) l 0 12 M \(30 * a) \(-14 * a) l 10 0 M \(35 * a) \(-19 * a) l 0 10", stroke: "#9cc4d6", strokeWidth: 3, opacity: 1 - h / 0.6)
      }
    }
    // ラップ (半透明の包みと、つやの線。外すと右上へ持ち上がって消える)
    let w = min(1, max(0, wrap))
    if w > 0.02 {
      let off = (1 - w)
      g(opacity: w, transform: [.translate(60 * off, -70 * off), .rotate(-20 * off)]) {
        rect(x: -80, y: -52, width: 160, height: 54, rx: 18, fill: "#dfeef5", stroke: "#9fb8c4", strokeWidth: 3, fillOpacity: 0.35)
        path("M -60 -42 Q -20 -48 20 -44", fill: "none", stroke: "#ffffff", strokeWidth: 4, opacity: 0.9)
        path("M 52 -50 l 10 -10 l 8 12", fill: "none", stroke: "#9fb8c4", strokeWidth: 3)
      }
    }
  }
}

// ---------- お皿 (幅 210 × 高さ 22) ----------

/// お皿の上の面の中央 (top。のせた物の底) と、右の縁 (gripR。手で持つ所)
let PLATE_PARTS = Parts(["top": Pt(0, -14), "gripR": Pt(100, -14)])

/// 平たいお皿
func Plate(x: Double, y: Double, scale: Double = 1, angle: Double = 0) {
  let palette = useGuide().palette
  Placed(x: x, y: y, scale: scale, angle: angle) {
    rect(x: -44, y: -6, width: 88, height: 6, rx: 3, fill: "#e6dccb", strokeWidth: 4)
    path("M -105 -20 Q -98 -5 -60 -5 L 60 -5 Q 98 -5 105 -20 Z", fill: "#f8f4ea")
    path("M -88 -12 Q 0 -8 88 -12", fill: "none", stroke: palette.primary, strokeWidth: 4, opacity: 0.5)
  }
}

/// お皿にのせたごはん (お皿の底の中心が x, y)
func DishWithRice(x: Double, y: Double, scale: Double = 1, heat: Double, wrap: Double, loose: Double = 0, amount: Double = 1) {
  Plate(x: x, y: y, scale: scale)
  FrozenRice(x: x + PLATE_PARTS.top.x * scale, y: y + PLATE_PARTS.top.y * scale, scale: scale * 0.9, heat: heat, wrap: wrap, loose: loose, amount: amount)
}

// ---------- お茶わん (幅 150 × 高さ 80) ----------

/// お茶わんの口の中央 (rim) と、ごはんを盛った山の上 (top)
let CHAWAN_PARTS = Parts(["rim": Pt(0, -74), "top": Pt(0, -112)])

/// お茶わん。fill: ごはんの量 (0 空〜1 山盛り)
func Chawan(x: Double, y: Double, scale: Double = 1, angle: Double = 0, fill: Double) {
  let palette = useGuide().palette
  let f = min(1, max(0, fill))
  Placed(x: x, y: y, scale: scale, angle: angle) {
    // ごはんの山 (口より上に盛り上がる)
    if f > 0.02 {
      let top = -74 - 40 * f
      path("M -66 -74 C -60 \(top + 6) -24 \(top) 0 \(top) C 24 \(top) 60 \(top + 6) 66 -74 Z", fill: "#fbf7ee")
      for gx in [-34.0, -8, 20, 42] where f > 0.4 { ellipse(cx: gx, cy: -82 - 20 * f + abs(gx) * 0.12, rx: 6, ry: 3.5, fill: "#ffffff", strokeWidth: 2) }
    }
    rect(x: -34, y: -10, width: 68, height: 10, rx: 4, fill: "#e6dccb", strokeWidth: 5)
    path("M -75 -74 C -72 -30 -40 -8 0 -8 C 40 -8 72 -30 75 -74 Z", fill: "#f3ede1")
    path("M -66 -50 Q 0 -36 66 -50", fill: "none", stroke: palette.primary, strokeWidth: 7, opacity: 0.7)
    ellipse(cx: 0, cy: -74, rx: 75, ry: 10, fill: f > 0.02 ? Paint("none") : Paint("#e6dccb"), strokeWidth: 5)
  }
}

// ---------- 見本 (jgv preview) ----------

let PROPS_PREVIEW: [PreviewItem] = [
  PreviewItem(name: "FrozenRice", note: "heat 0 wrap 1", scale: 1.3, parts: RICE_PARTS) { x, y, s in FrozenRice(x: x, y: y, scale: s, heat: 0, wrap: 1) },
  PreviewItem(name: "FrozenRice", note: "heat 1 wrap 0.4 loose 1", scale: 1.3, parts: RICE_PARTS) { x, y, s in FrozenRice(x: x, y: y, scale: s, heat: 1, wrap: 0.4, loose: 1) },
  PreviewItem(name: "DishWithRice", note: "heat 0", scale: 1.2, parts: PLATE_PARTS) { x, y, s in DishWithRice(x: x, y: y, scale: s, heat: 0, wrap: 1) },
  PreviewItem(name: "Chawan", note: "fill 0", scale: 1.4, parts: CHAWAN_PARTS) { x, y, s in Chawan(x: x, y: y, scale: s, fill: 0) },
  PreviewItem(name: "Chawan", note: "fill 1", scale: 1.4, parts: CHAWAN_PARTS) { x, y, s in Chawan(x: x, y: y, scale: s, fill: 1) },
  PreviewItem(name: "MicrowaveSvg", note: "閉 / 600W", scale: 0.55, parts: MW_PARTS) { x, y, s in MicrowaveSvg(x: x, y: y, scale: s, open: 0, on: 0, display: "600W", dish: (0, 1)) },
  PreviewItem(name: "MicrowaveSvg", note: "開 0.7 / 明かり", scale: 0.55, parts: MW_PARTS) { x, y, s in MicrowaveSvg(x: x, y: y, scale: s, open: 0.7, on: 1, display: "1:23", dish: (0, 1)) },
]
