// マグの内側 (拡大カード用、少し上から見た図) とスポンジ
import JGVKit

/** マグの内側。stain: 茶渋 (0〜1)、soda: 重曹 (0〜1)、paste: ペースト化 (0〜1)、foam: 泡、water: 水 (0〜1)、shine: ピカピカ */
func MugInside(x: Double, y: Double, rx: Double, ry: Double, stain: Double = 0, soda: Double = 0, paste: Double = 0, foam: Double = 0, water: Double = 0, shine: Double = 0) {
  let frame = useCurrentFrame()
  let palette = useGuide().palette
  g {
    path("M \(x - rx - 24) \(y) L \(x - rx + 10) \(y + ry + 120) Q \(x) \(y + ry + 170) \(x + rx - 10) \(y + ry + 120) L \(x + rx + 24) \(y) Z", fill: palette.accent, stroke: palette.ink, strokeWidth: 6)
    ellipse(cx: x, cy: y, rx: rx + 24, ry: ry + 14, fill: "#f7dfbc", stroke: palette.ink, strokeWidth: 6)
    ellipse(cx: x, cy: y, rx: rx, ry: ry, fill: "#f4ead6")
    g(clip: .ellipse(cx: x, cy: y, rx: rx, ry: ry)) {
      // 茶渋: 内側の壁のリングとまだら
      g(opacity: stain) {
        ellipse(cx: x, cy: y + 10, rx: rx - 10, ry: ry - 6, fill: "none", stroke: "#8a5a34", strokeWidth: 34, opacity: 0.75)
        for i in 0..<12 {
          ellipse(cx: x + (random("s\(i)") - 0.5) * rx * 1.6, cy: y + (random("t\(i)") - 0.5) * ry * 1.4, rx: 20 + random("u\(i)") * 26, ry: 10 + random("v\(i)") * 12, fill: "#9a6a40", opacity: 0.5)
        }
      }
      if water > 0 { ellipse(cx: x, cy: y, rx: rx, ry: ry, fill: "#9fd3e6", opacity: 0.55 * water) }
    }
    // 重曹とペースト
    if soda > 0 {
      g {
        ellipse(cx: x, cy: y + 20, rx: 110 * soda, ry: 50 * soda, fill: "#ffffff", stroke: "#d6d0c2", strokeWidth: 3)
        if paste > 0 { ellipse(cx: x - 20, cy: y + 8, rx: 50 * paste, ry: 16 * paste, fill: "#ffffff", opacity: 0.9) }
        if paste > 0.5 { path("M \(x - 60) \(y + 30) q 60 18 120 0", fill: "none", stroke: "#cfe6ee", strokeWidth: 5, opacity: paste) }
      }
    }
    if foam > 0 {
      for i in 0..<14 {
        let a = random("f\(i)") * Double.pi * 2 + frame * 0.03
        let d = 0.4 + random("g\(i)") * 0.5
        circle(cx: x + cos(a) * rx * d, cy: y + sin(a) * ry * d, r: 8 + random("h\(i)") * 10, fill: "#fff", stroke: "#c9d7dc", strokeWidth: 2, opacity: foam)
      }
    }
    if shine > 0 {
      g(stroke: "#fff", strokeWidth: 8, strokeLinecap: .round, opacity: shine) {
        path("M \(x - rx * 0.5) \(y - ry * 0.3) l 60 -10")
        path("M \(x + rx * 0.3) \(y + ry * 0.2) l 40 -6")
      }
    }
  }
}

/** スポンジ (原点 = 底の中心、横から) */
func Sponge(x: Double, y: Double, scale: Double = 1, angle: Double = 0) {
  Placed(x: x, y: y, scale: scale, angle: angle) {
    rect(x: -70, y: -60, width: 140, height: 44, rx: 10, fill: "#f2c94c")
    rect(x: -70, y: -18, width: 140, height: 18, rx: 6, fill: "#3f8f5a")
    for cx in [-40.0, 0, 40] {
      circle(cx: cx, cy: -40, r: 5, fill: "#d9a92f", stroke: "none")
    }
  }
}
