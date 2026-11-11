// おにぎりの食材と道具 (真上から見た図、原点 = 中心)
import Foundation
import JGVKit

/// ご飯の輪郭: tri = 0 で丸、1 で角の丸い三角 (rot = 頂点の向き、度)
func ricePath(_ cx: Double, _ cy: Double, _ s: Double, _ tri: Double, _ rot: Double = -90) -> String {
  var pts: [String] = []
  for i in 0..<72 {
    let th = (Double(i) / 72) * Double.pi * 2
    let phi = jsMod(jsMod((th * 180) / Double.pi - rot, 120) + 120, 120) - 60
    let poly = (s * 1.3 * 0.5) / cos((phi * Double.pi) / 180)
    let r = (1 - tri) * s + tri * (0.82 * poly + 0.18 * s * 1.05)
    pts.append(String(format: "%.1f %.1f", cx + cos(th) * r, cy + sin(th) * r))
  }
  return "M \(pts.joined(separator: " L ")) Z"
}

/// ご飯 (dent: 真ん中のくぼみ、ume: 梅干し、cover: 上からかぶせたご飯、nori: 海苔 0〜1)
func Rice(
  x: Double, y: Double, s: Double, tri: Double = 0, rot: Double = -90, dent: Double = 0, ume: Double = 0,
  cover: Double = 0, nori: Double = 0, id: String = "rice"
) {
  let palette = useGuide().palette
  let d = ricePath(x, y, s, tri, rot)
  g {
    path(d, fill: "#6b4a25", opacity: 0.18, transform: [.translate(s * 0.08, s * 0.1)])
    path(d, fill: "#fbfaf5")
    g(clip: .path(d)) {
      for i in 0..<70 {
        let gx = x + (random("\(id)x\(i)") - 0.5) * s * 2.4
        let gy = y + (random("\(id)y\(i)") - 0.5) * s * 2.4
        ellipse(cx: gx, cy: gy, rx: s * 0.07, ry: s * 0.035, fill: "none", stroke: "#e3ddcf", strokeWidth: 2,
                transform: [.rotate(random("\(id)r\(i)") * 180, gx, gy)])
      }
      if dent > 0 { circle(cx: x, cy: y, r: s * 0.32, fill: "#e6dfcf", opacity: dent) }
      // 海苔: 下側から巻く
      if nori > 0 {
        g {
          rect(x: x - s * 1.5, y: y + s * 1.3 - s * 1.0 * nori, width: s * 3, height: s * 1.6, fill: "#1f3324")
          path("M \(x - s * 0.6) \(y + s * 1.3 - s * 1.0 * nori + 20) h \(s * 1.2)", stroke: "#3a5a40", strokeWidth: 4, opacity: 0.7)
        }
      }
    }
    if ume > 0 { Umeboshi(x: x, y: y, r: s * 0.22, opacity: ume) }
    if cover > 0 {
      g(opacity: cover) {
        circle(cx: x, cy: y, r: s * 0.34, fill: "#fbfaf5", stroke: "#e3ddcf", strokeWidth: 3)
        ellipse(cx: x - 8, cy: y - 6, rx: s * 0.07, ry: s * 0.035, fill: "none", stroke: "#e3ddcf", strokeWidth: 2)
      }
    }
    path(d, fill: "none", stroke: palette.ink, strokeWidth: 5, strokeLinejoin: .round)
  }
}

func Umeboshi(x: Double, y: Double, r: Double, opacity: Double = 1) {
  let palette = useGuide().palette
  g(opacity: opacity) {
    circle(cx: x, cy: y, r: r, fill: "#c8384a", stroke: palette.ink, strokeWidth: 4)
    path("M \(x - r * 0.4) \(y - r * 0.2) q \(r * 0.4) \(r * 0.3) \(r * 0.8) 0", fill: "none", stroke: "#8f2032", strokeWidth: 3)
    ellipse(cx: x - r * 0.35, cy: y - r * 0.4, rx: r * 0.22, ry: r * 0.12, fill: "#fff", opacity: 0.6)
  }
}

/// ラップ: open = 広げる (0〜1)、wrap = 包む (0〜1: ご飯の形に縮む)
func Wrap(x: Double, y: Double, size: Double, open: Double, wrap: Double = 0, riceS: Double = 100, tri: Double = 0, rot: Double = -90) {
  if open <= 0 { return }
  let w = size * open * (1 - wrap) + riceS * 2.3 * wrap
  let r = 10 + 60 * wrap
  g(opacity: min(1, open * 1.4)) {
    if wrap < 0.95 {
      rect(x: x - w / 2, y: y - w / 2, width: w, height: w, rx: r, fill: "#e9f3f6", stroke: "#a9c4cc", strokeWidth: 3, fillOpacity: 0.55)
    }
    if wrap > 0.5 {
      g(opacity: (wrap - 0.5) * 2) {
        path(ricePath(x, y, riceS * 1.12, tri, rot), fill: "#e9f3f6", stroke: "#a9c4cc", strokeWidth: 3, fillOpacity: 0.35)
        path("M \(x - 18) \(y - riceS * 1.2) q 18 -30 36 0", fill: "none", stroke: "#a9c4cc", strokeWidth: 4)
      }
    }
    path("M \(x - w / 2 + 20) \(y - w / 2 + 30) l \(w * 0.3) \(w * 0.15)", stroke: "#fff", strokeWidth: 6, strokeLinecap: .round, opacity: 0.6 * (1 - wrap))
  }
}

/// 海苔の束 (原点 = 中心)
func NoriStack(x: Double, y: Double, count: Int = 3) {
  let palette = useGuide().palette
  g {
    for i in 0..<count {
      let di = Double(i)
      rect(x: x - 110 + di * 6, y: y - 55 - di * 6, width: 220, height: 110, rx: 6, fill: "#1f3324", stroke: palette.ink, strokeWidth: 4)
    }
  }
}

/// しゃもじ (原点 = へらの中心、angle = 柄の向き)
let SHAMOJI_GRIP = Pt(0, 170)
func Shamoji(x: Double, y: Double, angle: Double = 0, rice: Double = 0) {
  let palette = useGuide().palette
  g(stroke: palette.ink, strokeWidth: 5, strokeLinejoin: .round, transform: [.translate(x, y), .rotate(angle)]) {
    rect(x: -18, y: 40, width: 36, height: 150, rx: 14, fill: "#e8d3a8")
    ellipse(cx: 0, cy: 0, rx: 56, ry: 64, fill: "#efdcb4")
    if rice > 0 { ellipse(cx: 0, cy: -4, rx: 44 * rice, ry: 46 * rice, fill: "#fbfaf5", stroke: "#e3ddcf", strokeWidth: 3) }
  }
}
