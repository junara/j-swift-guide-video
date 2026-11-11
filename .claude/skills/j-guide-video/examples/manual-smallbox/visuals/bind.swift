// この動画の部品の描き方と名前 (全工程のキューで共通)。組み立て説明書: 手は描かず、H の位置にドライバーの先を描く
import JGVKit

private let ISO = Iso(ox: 760, oy: 470, s: 12)   // 1 cm = 12 px
private let SCREWS = [(30.0, 5.0, 6.5), (30.0, 15.0, 6.5)]
private func pt(_ x: Double, _ y: Double, _ z: Double) -> Pt { isoPoint(ISO, x, y, z) }

let BIND = CueBinding(
  keys: ["bottom.o", "side.o", "screw.o", "sideA.u", "sideB.u", "s1", "s2", "driver", "spin"],
  points: [
    "rest": { _ in Pt(1500, 860) },
    "parts": { _ in Pt(1340, 250) },
    "s1": { _ in pt(SCREWS[0].0 + 2, SCREWS[0].1, SCREWS[0].2) }, "s2": { _ in pt(SCREWS[1].0 + 2, SCREWS[1].1, SCREWS[1].2) },
    "tagA": { _ in pt(15, 10, 1.5) }, "tagB": { s in pt(15 * s["sideB.u"] + 30, 10, 13.5 + 12 * s["sideB.u"]) },
    "box.top": { _ in pt(15, 10, 20) }, "box.badge": { _ in pt(34, 0, 20) },
  ],
  hand: .none,
  draw: { s in
    let a = s["sideA.u"], b = s["sideB.u"]
    // 奥 (x・y が小さい) から手前の順: 側板 A → 底板 → 側板 B → ネジ
    IsoBox(iso: ISO, x: -12 * a, y: 0, z: 1.5 + 5 * a, w: 1.5, d: 20, h: 12, fill: "#f6eddd", opacity: s["side.o"])
    IsoBox(iso: ISO, x: 0, y: 0, z: 0, w: 30, d: 20, h: 1.5, fill: "#efe2c8", opacity: s["bottom.o"])
    IsoBox(iso: ISO, x: 28.5 + 12 * b, y: 0, z: 1.5 + 5 * b, w: 1.5, d: 20, h: 12, fill: "#f6eddd", opacity: s["side.o"])
    if a > 0.02 && a < 0.98 { DashArrow(from: pt(-12, 10, 18), to: pt(0, 10, 8)) }
    if b > 0.02 && b < 0.98 { DashArrow(from: pt(42, 10, 18), to: pt(30, 10, 8)) }
    for (i, sc) in SCREWS.enumerated() {
      let d = s["s\(i + 1)"]   // 0 差す前 (外に出ている) → 1 締めた
      let p = pt(sc.0 + 4 * (1 - d), sc.1, sc.2)
      g(opacity: s["screw.o"]) { Screw(x: p.x, y: p.y, angle: -30, scale: 1.2) }
    }
  },
  front: { s in
    let h = Pt(s["H.x"], s["H.y"])
    if s["driver"] > 0.01 {
      g(opacity: s["driver"]) { Screwdriver(tip: h, angle: -30, spin: s.on("spin")) }
      if s.on("spin") { RotateArrow(x: h.x + 40, y: h.y - 70, spin: true) }
    }
  }
)
