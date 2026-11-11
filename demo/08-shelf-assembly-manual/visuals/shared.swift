// カラーボックスの部品 (単位 cm) と等角図の配置
import JGVKit

let ISO = Iso(ox: 880, oy: 700, s: 4.4)
private let T = 1.8 // 板の厚み

enum PartId: String { case D, AL, B, C1, C2, T, AR }

struct PartSpec {
  var x: Double, y: Double, z: Double, w: Double, d: Double, h: Double
  var fill: Paint
  var letter: String
}

/// 奥から手前の順 (この順で描くと重なりが正しくなる)
let PARTS: [PartId: PartSpec] = [
  .D: PartSpec(x: 0, y: -0.6, z: 0, w: 40, d: 0.6, h: 90, fill: "#e9e4d8", letter: "D"),
  .AL: PartSpec(x: 0, y: 0, z: 0, w: T, d: 30, h: 90, fill: "#f1e6d2", letter: "A"),
  .B: PartSpec(x: T, y: 0, z: 0, w: 40 - 2 * T, d: 30, h: T, fill: "#f1e6d2", letter: "B"),
  .C1: PartSpec(x: T, y: 1, z: 29, w: 40 - 2 * T, d: 28, h: T, fill: "#f6eddd", letter: "C"),
  .C2: PartSpec(x: T, y: 1, z: 59, w: 40 - 2 * T, d: 28, h: T, fill: "#f6eddd", letter: "C"),
  .T: PartSpec(x: T, y: 0, z: 90 - T, w: 40 - 2 * T, d: 30, h: T, fill: "#f1e6d2", letter: "B"),
  .AR: PartSpec(x: 40 - T, y: 0, z: 0, w: T, d: 30, h: 90, fill: "#f1e6d2", letter: "A"),
]
let ORDER: [PartId] = [.D, .AL, .B, .C1, .C2, .T, .AR]

typealias Off3 = (Double, Double, Double)

struct PartState {
  var off: Off3?
  var opacity: Double?
  var dashed: Bool?
  init(off: Off3? = nil, opacity: Double? = nil, dashed: Bool? = nil) { self.off = off; self.opacity = opacity; self.dashed = dashed }
}

/// 部品ごとのずらし量 (off) と表示 (opacity) を指定してカラーボックスを描く
func ColorBox(state: [PartId: PartState]) {
  g {
    for id in ORDER {
      let p = PARTS[id]!
      guard let s = state[id], (s.opacity ?? 1) > 0 else { continue }
      let (dx, dy, dz) = s.off ?? (0, 0, 0)
      IsoBox(iso: ISO, x: p.x + dx, y: p.y + dy, z: p.z + dz, w: p.w, d: p.d, h: p.h, fill: p.fill, opacity: s.opacity ?? 1, dashed: s.dashed ?? false)
    }
  }
}

/// 部品の中心 (画面座標)
func partCenter(_ id: PartId, _ off: Off3 = (0, 0, 0)) -> Pt {
  let p = PARTS[id]!
  return isoPoint(ISO, p.x + p.w / 2 + off.0, p.y + p.d / 2 + off.1, p.z + p.h / 2 + off.2)
}

/// 右の側板の外側の面 (x = 40) に打つネジの位置: 板の高さ z ごとに奥・手前の 2 本
func screwsOnRight(_ zs: [Double]) -> [Pt] { zs.flatMap { z in [isoPoint(ISO, 40, 7, z), isoPoint(ISO, 40, 23, z)] } }
/// 左の側板 (外側は見えないので、上面の端に印を付ける)
func screwsOnLeft(_ zs: [Double]) -> [Pt] { zs.flatMap { z in [isoPoint(ISO, 0, 7, z), isoPoint(ISO, 0, 23, z)] } }

let LIST = (x: 1330.0, y: 250.0, w: 490.0)
