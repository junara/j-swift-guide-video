// この動画の道具の描き方と名前 (全工程のキューで共通)。手元俯瞰: 右手 = H、左手 = C (どちらも TopHand で描く)
import JGVKit

private let BOARD = Pt(820, 560), BOWL = Pt(1440, 560), SALT = Pt(1640, 330), KNIFE_REST = Pt(980, 810)
private let OFF = topOffscreenY()
private func knife(_ s: CueState) -> Pt {
  let v = s.obj("veg"), cut = Pt(v.x + vegCutX(.cucumber, s["cuts"]) * v.s, v.y + 70)
  return Pt(KNIFE_REST.x + (cut.x - KNIFE_REST.x) * s["knife.held"], KNIFE_REST.y + (cut.y - KNIFE_REST.y) * s["knife.held"])
}
private func slices(_ x: Double, _ y: Double, _ n: Int, _ spread: Double) {
  for i in 0 ..< n {
    let a = Double(i) * 2.4, d = spread * (0.3 + 0.7 * Double(i % 5) / 4)
    circle(cx: x + cos(a) * d, cy: y + sin(a) * d * 0.8, r: 24, fill: "#cfe6a8", stroke: "#4f7d3a", strokeWidth: 4)
  }
}

let BIND = CueBinding(
  keys: ["cuts", "knife.held", "knife.lift", "salt", "bowl.level"],
  objects: ["veg", "pile"],
  points: [
    "rest": { _ in Pt(1300, OFF + 60) },
    "c.away": { _ in Pt(500, OFF + 60) },
    "knife.grip": { s in let k = knife(s); return place(k.x, k.y, 1, 0, TOP_KNIFE_PARTS.grip) },
    "veg.press": { s in let v = s.obj("veg"); return Pt(min(v.x + vegCutX(.cucumber, s["cuts"]) * v.s - 150, v.x + 60), v.y - 10) },
    "pile.side": { s in let p = s.obj("pile"); return Pt(p.x - 150, p.y + 10) },
    "salt": { _ in Pt(SALT.x, SALT.y + 10) },
    "bowl.top": { _ in Pt(BOWL.x + 20, BOWL.y - 40) },
    "bowl.badge": { _ in Pt(BOWL.x + 150, BOWL.y - 170) },
    "veg.top": { s in let v = s.obj("veg"); return Pt(v.x, v.y - 60) },
  ],
  places: ["BOARD": (BOARD.x, BOARD.y, 1), "BOWL": (BOWL.x, BOWL.y, 0.6)],
  hand: .none,
  draw: { s in
    TopCuttingBoard(x: BOARD.x, y: BOARD.y)
    TopBowl(x: BOWL.x, y: BOWL.y, r: 170)
    if s["bowl.level"] > 0.01 { g(opacity: s["bowl.level"]) { slices(BOWL.x, BOWL.y, 14, 90) } }
    Sprinkle(x: BOWL.x, y: BOWL.y, r: 110, amount: s["salt"])
    TopBowl(x: SALT.x, y: SALT.y, r: 60, grains: "#ffffff")
    if s.on("veg.vis") { let v = s.obj("veg"); TopVeg(x: v.x, y: v.y, kind: .cucumber, scale: v.s, cuts: s["cuts"]) }
    if s.on("pile.vis") { let p = s.obj("pile"); slices(p.x, p.y, 14, 90 * p.s) }
    let k = knife(s)
    TopKnife(x: k.x, y: k.y, angle: s["knife.held"] < 0.5 ? -90 * (1 - s["knife.held"] * 2) : 0, lift: abs(s["knife.lift"]))
  },
  front: { s in
    let h = Pt(s["H.x"], s["H.y"]), c = Pt(s["C.x"], s["C.y"])
    if h.y < OFF { TopHand(from: topArmFrom(h, .R), to: h, angle: -8, cup: 0.6) }
    if c.y < OFF { TopHand(from: topArmFrom(c, .L), to: c, angle: 70, cup: 0.8, side: .L) }
  }
)
