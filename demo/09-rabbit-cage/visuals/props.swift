// この動画専用の道具: ケージ、うさぎ、サークル、トイレ、食器、おもちゃ、タオル、ペットシーツ (ゴミ袋・掃除シート・ブラシ・蛇口などは kit の Household.swift)
import Foundation
import JGVKit

private let HAY: Paint = "#c9b55a"
private let HAY_FRESH: Paint = "#a8c25c"
private let FUR: Paint = "#ece4d6"
private let STAIN: Paint = "#a88a5c"
private let BARS: Paint = "#7d878b"

private func useSec() -> Double {
  let frame = useCurrentFrame()
  let fps = useVideoConfig().fps
  return frame / fps
}

// ---------- ケージ (原点 = 底の中心、幅 600 × 高さ 380) ----------
// 奥 (CageBack) → 中身・うさぎ → 手前の金網 (CageFront) の順に描く。中身の床は y = CAGE_FLOOR
let CAGE_FLOOR: Double = -55
let CAGE_PARTS = Parts([
  "latch": Pt(96, -212),
  "toilet": Pt(-185, CAGE_FLOOR),
  "rabbit": Pt(10, CAGE_FLOOR),
  "bowl": Pt(140, CAGE_FLOOR),
  "toy": Pt(228, CAGE_FLOOR),
  "hay": Pt(-210, -270),
  "bottle": Pt(252, -300),
  "floorL": Pt(-260, CAGE_FLOOR),
  "floorR": Pt(260, CAGE_FLOOR),
])
/// 扉の開き具合 door (0〜1) のときの、扉の取っ手側の端 (ローカル x)
func doorEdgeX(_ door: Double) -> Double { -80 + 176 * cos(door * 1.35) }

/// 奥の壁・床・牧草入れ・給水ボトル。hay: 牧草 (0〜1)、fresh: 新しい牧草、water: 水 (0〜1)、dirt: 床と壁の汚れ (0〜1)
func CageBack(x: Double, y: Double, scale: Double = 1, angle: Double = 0, hay: Double = 0.3, fresh: Bool = false, water: Double = 0.3, dirt: Double = 0) {
  let t = useSec()
  Placed(x: x, y: y, scale: scale, angle: angle) {
    rect(x: -292, y: -372, width: 584, height: 334, rx: 22, fill: "#f3eee2", stroke: "none")
    for i in 0 ..< 15 {
      let lx = -266 + Double(i) * 38
      line(x1: lx, y1: -366, x2: lx, y2: -70, stroke: "#ddd6c6", strokeWidth: 3)
    }
    // 床 (少し上から見た面)
    path("M -292 -72 L 292 -72 L 300 -40 L -300 -40 Z", fill: "#e7dbbd", strokeWidth: 4)
    if dirt > 0.01 {
      g(stroke: "none", opacity: dirt) {
        for x in [-120.0, 40, 180] {
          ellipse(cx: x, cy: -56, rx: 34, ry: 8, fill: STAIN, opacity: 0.6)
        }
        for (i, x) in [-60.0, 120].enumerated() {
          ellipse(cx: x, cy: -110 - Double(i) * 20, rx: 18, ry: 12, fill: STAIN, opacity: 0.4)
        }
      }
    }
    // 牧草入れ
    g(transform: [.translate(-210, -270)]) {
      if hay > 0.01 {
        for i in 0 ..< 16 {
          if Double(i) / 16 > hay { continue }
          let x = -48 + random("hy\(i)") * 96
          let y = -18 + random("hz\(i)") * 34 - hay * 14
          let a = (random("ha\(i)") - 0.5) * 120
          let rad = (a * Double.pi) / 180
          line(x1: x, y1: y, x2: x + cos(rad) * 26, y2: y + sin(rad) * 26, stroke: fresh ? HAY_FRESH : HAY, strokeWidth: 5)
        }
      }
      path("M -60 -30 L -40 40 L 40 40 L 60 -30", fill: "none", stroke: BARS, strokeWidth: 5)
      path("M -30 -30 L -18 40 M 0 -30 V 40 M 30 -30 L 18 40 M -50 5 H 50", fill: "none", stroke: BARS, strokeWidth: 3)
    }
    // 給水ボトル (右の壁に掛ける)
    g(transform: [.translate(252, -300)]) {
      rect(x: -20, y: -30, width: 40, height: 140, rx: 16, fill: "#eef6f8", strokeWidth: 5)
      rect(x: -17, y: -27 + 134 * (1 - water), width: 34, height: 134 * water, rx: 13, fill: "#8fcbe6", stroke: "none")
      if water > 0.05 {
        ellipse(cx: -6, cy: 20 + 60 * (1 - water) + sin(t * 3) * 4, rx: 4, ry: 4, fill: "#fff", stroke: "none", opacity: 0.8)
      }
      rect(x: -20, y: -30, width: 40, height: 140, rx: 16, fill: "none", strokeWidth: 5)
      rect(x: -14, y: 110, width: 28, height: 16, rx: 4, fill: "#d98a5c", strokeWidth: 4)
      path("M 0 126 L -4 160", stroke: "#b9c0c2", strokeWidth: 7)
      circle(cx: -4, cy: 162, r: 5, fill: "#b9c0c2", strokeWidth: 3)
    }
  }
}

/// 手前の金網と扉、受け皿。door: 扉の開き具合 (0〜1)
func CageFront(x: Double, y: Double, scale: Double = 1, angle: Double = 0, door: Double = 0) {
  let sx = cos(door * 1.35)
  Placed(x: x, y: y, scale: scale, angle: angle) {
    g(stroke: BARS, strokeWidth: 4) {
      var bx: Double = -276
      while bx <= 276 {
        let inDoor = bx > -80 && bx < 96
        if !inDoor {
          line(x1: bx, y1: -372, x2: bx, y2: -42)
        } else {
          line(x1: bx, y1: -372, x2: bx, y2: -336)
          line(x1: bx, y1: -84, x2: bx, y2: -42)
        }
        bx += 30
      }
    }
    path("M -300 -230 H -82 M 98 -230 H 300", stroke: BARS, strokeWidth: 5)
    // 外枠と上の取っ手
    path("M -300 -40 V -350 Q -300 -380 -270 -380 H 270 Q 300 -380 300 -350 V -40", fill: "none")
    path("M -60 -380 Q -60 -420 0 -420 Q 60 -420 60 -380", fill: "none", strokeWidth: 8)
    // 扉 (左の蝶番で手前に開く)
    g(transform: [.translate(-80, 0), .scale(max(0.06, sx), 1), .translate(80, 0)]) {
      rect(x: -80, y: -334, width: 176, height: 250, rx: 8, fill: "none", stroke: "#5f6a6e", strokeWidth: 9)
      for i in 0 ..< 5 {
        let lx = -50 + Double(i) * 30
        line(x1: lx, y1: -330, x2: lx, y2: -88, stroke: BARS, strokeWidth: 4)
      }
      rect(x: 84, y: -232, width: 22, height: 40, rx: 6, fill: "#d98a5c", strokeWidth: 4)
    }
    // 受け皿
    path("M -306 -44 H 306 L 296 -6 Q 292 0 284 0 H -284 Q -292 0 -296 -6 Z", fill: "#9fbfcc")
    path("M -280 -22 H 280", stroke: "#7fa0ae", strokeWidth: 4)
  }
}

/// 床に落ちた牧草と抜け毛。gather: 集める (0〜1 で to へ寄る)、amount: 残り (0〜1)
func Litter(x: Double, y: Double, w: Double, gather: Double = 0, to: Pt? = nil, amount: Double = 1, count: Int = 18, seed: String = "lt", scale: Double = 1) {
  if amount < 0.01 { return }
  let gg = gather * gather * (3 - 2 * gather)
  g(strokeLinecap: .round, opacity: amount) {
    for i in 0 ..< count {
      let bx = x - w / 2 + random("\(seed)x\(i)") * w
      let by = y + (random("\(seed)y\(i)") - 0.5) * 14 * scale
      let tx = to.map { $0.x + (random("\(seed)g\(i)") - 0.5) * 50 * scale } ?? bx
      let ty = to.map { $0.y + (random("\(seed)h\(i)") - 0.5) * 20 * scale } ?? by
      let cx = bx + (tx - bx) * gg
      let cy = by + (ty - by) * gg
      let a = random("\(seed)a\(i)") * Double.pi
      let len = 16 * scale
      if i % 3 == 0 {
        ellipse(cx: cx, cy: cy, rx: 9 * scale, ry: 5 * scale, fill: FUR, stroke: "#b9ae9c", strokeWidth: 2 * scale)
      } else {
        line(x1: cx - cos(a) * len, y1: cy - sin(a) * len * 0.4, x2: cx + cos(a) * len, y2: cy + sin(a) * len * 0.4, stroke: HAY, strokeWidth: 5 * scale)
      }
    }
  }
}

// ---------- うさぎ (原点 = 足元の中心、左向き。幅 約 180 × 高さ 約 190) ----------
// held: 抱えられている (足がぶら下がる)、nibble: 口をもぐもぐ、flip: 右向き、happy: ほっぺ
func Rabbit(x: Double, y: Double, scale: Double = 1, angle: Double = 0, held: Double = 0, nibble: Bool = false, flip: Bool = false) {
  let t = useSec()
  let palette = useGuide().palette
  let body: Paint = "#d9b48f"
  let light: Paint = "#f6ecdf"
  let breath = 1 + sin(t * 5) * 0.015
  let ear = sin(t * 1.7) * 4 + (sin(t * 0.6) > 0.85 ? sin(t * 20) * 6 : 0)
  let nose = nibble ? sin(t * 18) * 2 : sin(t * 9) * 0.8
  let blink: Double = Int(floor(t * 30)) % 95 < 3 ? 0.2 : 1
  Placed(x: x, y: y, scale: scale, angle: angle) {
    g(transform: flip ? [.scale(-1, 1)] : []) {
      g(transform: [.scale(1, breath)]) {
        circle(cx: 78, cy: -64, r: 17, fill: light)
        let footY = -12 + held * 16
        ellipse(cx: 40, cy: footY, rx: 36, ry: 13, fill: body, transform: [.rotate(held * 40, 40, footY)])
        ellipse(cx: 14, cy: -58, rx: 72, ry: 52, fill: body)
        ellipse(cx: -14, cy: -38, rx: 34, ry: 22, fill: light, stroke: "none")
        ellipse(cx: -40, cy: -8 + held * 12, rx: 16, ry: 9, fill: light)
        // 耳
        g(transform: [.rotate(18 + ear, -40, -128)]) {
          ellipse(cx: -40, cy: -168, rx: 15, ry: 46, fill: body)
          ellipse(cx: -40, cy: -164, rx: 6, ry: 32, fill: "#eeb3b0", stroke: "none")
        }
        g(transform: [.rotate(4 + ear * 0.6, -62, -128)]) {
          ellipse(cx: -62, cy: -170, rx: 15, ry: 46, fill: body)
          ellipse(cx: -62, cy: -166, rx: 6, ry: 32, fill: "#eeb3b0", stroke: "none")
        }
        // 頭
        ellipse(cx: -62, cy: -100, rx: 44, ry: 37, fill: body)
        ellipse(cx: -76, cy: -108, rx: 6, ry: 7 * blink, fill: palette.ink, stroke: "none")
        circle(cx: -78, cy: -111, r: 2, fill: "#fff", stroke: "none", opacity: blink)
        circle(cx: -56, cy: -88, r: 10, fill: palette.accent, stroke: "none", opacity: 0.35)
        ellipse(cx: -104, cy: -94 + nose, rx: 6, ry: 5, fill: "#e48f97", strokeWidth: 3)
        path("M -104 \(-89 + nose) q -2 8 -8 9 M -104 \(-89 + nose) q 3 8 8 8", fill: "none", strokeWidth: 3)
      }
    }
  }
}

// ---------- サークル (原点 = 底の中心、幅 260 × 高さ 140) ----------
func PenBack(x: Double, y: Double, scale: Double = 1, angle: Double = 0) {
  Placed(x: x, y: y, scale: scale, angle: angle) {
    path("M -130 -140 H 130", stroke: "#b9ad97", strokeWidth: 8)
    for i in 0 ..< 11 {
      let lx = -125 + Double(i) * 25
      line(x1: lx, y1: -140, x2: lx, y2: -28, stroke: "#d8cfbe", strokeWidth: 4)
    }
    path("M -138 -28 H 138 L 130 0 H -130 Z", fill: "#c9dba8", strokeWidth: 4)
  }
}
func PenFront(x: Double, y: Double, scale: Double = 1, angle: Double = 0) {
  Placed(x: x, y: y, scale: scale, angle: angle) {
    for i in 0 ..< 12 {
      let lx = -132 + Double(i) * 24
      line(x1: lx, y1: -112, x2: lx, y2: 0, stroke: "#b9ad97", strokeWidth: 5)
    }
    path("M -140 -112 H 140 M -140 -4 H 140", stroke: "#9c8f77", strokeWidth: 8)
    circle(cx: -140, cy: -112, r: 8, fill: "#9c8f77", strokeWidth: 3)
    circle(cx: 140, cy: -112, r: 8, fill: "#9c8f77", strokeWidth: 3)
  }
}

// ---------- うさぎ用トイレ (原点 = 底の中心、幅 156 × 高さ 110) ----------
// pellets: 排泄物 (0〜1)、soil: シーツ・砂の汚れ (0〜1)、sheet: 中のシーツの有無 (0〜1)、grime: 容器の汚れ、wet: 水滴
let TOILET_PARTS = Parts(["grip": Pt(70, -86), "lip": Pt(78, -60), "top": Pt(0, -66)])
func Toilet(
  x: Double, y: Double, scale: Double = 1, angle: Double = 0,
  pellets: Double = 0, soil: Double = 0, sheet: Double = 1, grime: Double = 0, wet: Double = 0, grate: Bool = true
) {
  let sheetColor: Paint = soil > 0.5 ? "#dcc77c" : "#fbfaf4"
  Placed(x: x, y: y, scale: scale, angle: angle) {
    path("M -78 -58 L -72 -104 Q 0 -116 72 -104 L 78 -58 Z", fill: "#cfe5dc")
    if sheet > 0.01 { rect(x: -72, y: -70, width: 144, height: 14, rx: 4, fill: sheetColor, strokeWidth: 3, opacity: sheet) }
    if grate { path("M -76 -66 H 76 M -50 -72 v 10 M -20 -72 v 10 M 10 -72 v 10 M 40 -72 v 10", stroke: "#8aa79b", strokeWidth: 4) }
    if pellets > 0.01 {
      for i in 0 ..< 9 where Double(i) / 9 < pellets {
        circle(cx: -56 + random("pl\(i)") * 112, cy: -74 - random("pm\(i)") * 6, r: 6, fill: "#6b4e33", strokeWidth: 2)
      }
    }
    path("M -78 -58 L 78 -58 L 68 0 L -68 0 Z", fill: "#b6d6ca")
    path("M -60 -36 H 60", stroke: "#9cc2b4", strokeWidth: 4)
    if grime > 0.01 {
      g(stroke: "none", opacity: grime) {
        ellipse(cx: -34, cy: -24, rx: 22, ry: 9, fill: STAIN, opacity: 0.6)
        ellipse(cx: 30, cy: -44, rx: 16, ry: 7, fill: STAIN, opacity: 0.5)
        ellipse(cx: 46, cy: -14, rx: 12, ry: 6, fill: STAIN, opacity: 0.5)
      }
    }
    if wet > 0.01 {
      for (i, wx) in [-46.0, -8, 28, 54].enumerated() {
        ellipse(cx: wx, cy: -30 + Double(i % 2) * 14, rx: 5, ry: 7, fill: "#cfeaf6", strokeWidth: 2, opacity: wet)
      }
    }
  }
}

/// ペットシーツ 1 枚 (原点 = 中心、幅 150 × 高さ 30 の板を少し上から見た形)。soil: 汚れ
func PetSheet(x: Double, y: Double, scale: Double = 1, angle: Double = 0, soil: Double = 0) {
  Placed(x: x, y: y, scale: scale, angle: angle) {
    path("M -75 -15 H 75 L 70 15 H -70 Z", fill: soil > 0.5 ? "#dcc77c" : "#fbfaf4", strokeWidth: 4)
    path("M -60 0 H 60", stroke: soil > 0.5 ? "#c2ad62" : "#cfe0ea", strokeWidth: 3, strokeDasharray: [6, 8])
    if soil > 0.5 { ellipse(cx: 14, cy: 0, rx: 28, ry: 8, fill: STAIN, stroke: "none", opacity: 0.5) }
  }
}

// ---------- 食器 (原点 = 底の中心、幅 100) ----------
let BOWL_PARTS = Parts(["grip": Pt(40, -36)])
func FoodBowl(x: Double, y: Double, scale: Double = 1, angle: Double = 0, food: Double = 0) {
  Placed(x: x, y: y, scale: scale, angle: angle) {
    if food > 0.01 { ellipse(cx: 0, cy: -42, rx: 38 * food, ry: 8, fill: "#9bb36a", strokeWidth: 3) }
    path("M -50 -40 H 50 L 36 0 H -36 Z", fill: "#e9e1d0")
    path("M -44 -24 H 44", stroke: "#d98a5c", strokeWidth: 6)
  }
}

// ---------- おもちゃ (牧草ボール、原点 = 底) ----------
let TOY_PARTS = Parts(["grip": Pt(0, -50)])
func Toy(x: Double, y: Double, scale: Double = 1, angle: Double = 0) {
  Placed(x: x, y: y, scale: scale, angle: angle) {
    circle(cx: 0, cy: -25, r: 25, fill: "#d8b278")
    path("M -24 -30 Q 0 -10 24 -30 M -20 -12 Q 0 -40 20 -12 M -6 -48 Q 10 -25 -6 -2", fill: "none", stroke: "#a87f45", strokeWidth: 3)
  }
}

// ---------- 乾いたタオル (たたんだ状態、原点 = 底の中心) ----------
func Towel(x: Double, y: Double, scale: Double = 1, angle: Double = 0) {
  Placed(x: x, y: y, scale: scale, angle: angle) {
    rect(x: -72, y: -56, width: 144, height: 30, rx: 12, fill: "#a9cbe0")
    rect(x: -76, y: -30, width: 152, height: 30, rx: 12, fill: "#a9cbe0")
    path("M -50 -41 H 50 M -54 -15 H 54", stroke: "#fbfaf4", strokeWidth: 6)
  }
}
/// 手に持ったタオル (原点 = つかんだ所)
func TowelCloth(x: Double, y: Double, scale: Double = 1, angle: Double = 0) {
  Placed(x: x, y: y, scale: scale, angle: angle) {
    path("M -40 -10 Q 0 -24 40 -10 L 52 70 Q 0 86 -52 70 Z", fill: "#a9cbe0")
    path("M -46 50 Q 0 64 46 50", fill: "none", stroke: "#fbfaf4", strokeWidth: 6)
  }
}

// ---------- 新しいペットシーツ (たたんで重ねた束、原点 = 底の中心) ----------
func SheetPack(x: Double, y: Double, scale: Double = 1, angle: Double = 0) {
  Placed(x: x, y: y, scale: scale, angle: angle) {
    for i in 0 ..< 3 {
      let k = Double(i)
      rect(x: -78 + k * 3, y: -20 - k * 20, width: 156 - k * 6, height: 22, rx: 6, fill: "#fbfaf4", strokeWidth: 4)
    }
    path("M -60 -50 H 60 M -62 -30 H 62 M -64 -10 H 64", stroke: "#8ec3e0", strokeWidth: 3, strokeDasharray: [6, 8])
  }
}
