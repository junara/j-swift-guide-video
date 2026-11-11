import JGVKit

private let Y = GUIDE.counterY
private let SPOUT = Pt(1010, 360), CMUG = Pt(1160, 690), SINK = Pt(1120, 560)
private func bubbles(_ x: Double, _ y: Double, _ w: Double, _ o: Double) {
  if o < 0.02 { return }
  g(opacity: o) { for i in 0 ..< 7 { let k = Double(i); circle(cx: x - w / 2 + w * k / 6, cy: y - 10 * sin(k * 1.7), r: 9 + 5 * sin(k * 2.3), fill: "#ffffff", stroke: "#9fb8c4", strokeWidth: 3) } }
}
private func held(_ s: CueState) -> Pt { Pt(s["C.x"] - SPONGE_PARTS.grip.x * 1.3, s["C.y"] - SPONGE_PARTS.grip.y * 1.3) }

let MUG_BIND = CueBinding(
  keys: ["stain", "wet", "mug.foam", "sponge.foam", "squeeze", "water", "water.mug", "soap", "csponge", "shine"],
  objects: ["sponge", "det", "mug", "towel"],
  points: [
    "items": { _ in Pt(700, Y - 230) },
    "sponge.top": { s in let o = s.obj("sponge"); return Pt(o.x, o.y - 50) },
    "towel.grip": { s in let o = s.obj("towel"); return Pt(o.x, o.y - 40 * o.s) },
    "mug.top": { s in let o = s.obj("mug"); return Pt(o.x, o.y - 150) },
    "mug.badge": { s in let o = s.obj("mug"); return Pt(o.x + 110, o.y - 230) },
    "c.away": { _ in Pt(1720, 560) }, "c.sleeve": { s in Pt(min(1660, s["C.x"] + 300), 790) },
    "c.wet": { _ in Pt(SPOUT.x, SPOUT.y + 170) }, "c.soap": { _ in Pt(820, 520) },
    "c.in": { _ in Pt(CMUG.x - 10, CMUG.y - 150) }, "c.rim": { _ in Pt(CMUG.x - 90, CMUG.y - 180) },
    "c.handle": { _ in Pt(CMUG.x + 150, CMUG.y - 110) }, "c.mug": { _ in Pt(CMUG.x, CMUG.y - 260) },
  ],
  places: ["SPONGE": (640, Y, 1), "DET": (770, Y, 0.8), "MUG": (930, Y, 0.75), "TOWEL": (1120, Y, 1), "WIPE": (930 + 30, Y - 90, 1)],
  draw: { s in
    for (o, w) in [("sponge", 120.0), ("det", 110), ("mug", 180), ("towel", 130)] where s.num["\(o).vis"] ?? 1 > 0.5 {
      let p = s.obj(o)
      if abs(p.y - Y) < 3 { Shadow(x: p.x, w: w * p.s) }
      switch o {
      case "sponge": Sponge(x: p.x, y: p.y, scale: p.s, foam: s["sponge.foam"])
      case "det": Detergent(x: p.x, y: p.y, scale: p.s)
      case "mug": Mug(x: p.x, y: p.y, scale: p.s, fill: 0.12 * s["stain"], drink: "#8a5a3a"); bubbles(p.x, p.y - 140 * p.s, 160 * p.s, s["mug.foam"])
      default: break
      }
    }
  },
  front: { s in
    let t = s.obj("towel")
    if s.num["towel.vis"] ?? 1 > 0.5 { Towel(x: t.x, y: t.y, scale: t.s) }
    if s["shine"] > 0.02 { let m = s.obj("mug"); Sparkles(x: m.x - 90, y: m.y - 200, w: 180, h: 160, on: s["shine"]) }
  },
  card: { s in
    Sink(x: SINK.x, y: SINK.y, w: 820, h: 300)
    Faucet(x: SPOUT.x, y: SPOUT.y, side: .left)
    Mug(x: CMUG.x, y: CMUG.y, scale: 1.1, fill: 0.12 * s["stain"], drink: "#8a5a3a")
    bubbles(CMUG.x, CMUG.y - 190, 230, s["mug.foam"])
    if s["wet"] > 0.02 { Drips(x: CMUG.x, y: CMUG.y - 120, w: 200, fall: 90, count: 6) }
    if s["soap"] > 0.02 { Detergent(x: 820, y: 470, scale: 1.1, angle: -140) }
    if s.on("water") { Stream(from: Pt(SPOUT.x, SPOUT.y + 4), to: s.on("water.mug") ? Pt(CMUG.x - 20, CMUG.y - 190) : Pt(s["C.x"], s["C.y"] - 30)) }
    if s.on("csponge") {
      let h = held(s)
      g(transform: [.translate(h.x, h.y), .scale(1.3, 1.3 * (1 - 0.3 * s["squeeze"])), .translate(-h.x, -h.y)]) { Sponge(x: h.x, y: h.y, foam: s["sponge.foam"]) }
      bubbles(h.x, h.y - 70, 150, s["sponge.foam"])
    }
  }
)
