import JGVKit

private let CTOP = 720.0, CBOWL = Pt(880, 720), CDISH = Pt(1290, 720), CS = 1.5, STICK = 0.75
private func stickOff(_ s: CueState) -> Pt { place(0, 0, STICK, -6 + 4 * sin(s["C.dx"] * 0.02), SAIBASHI_PARTS.grip) }
private func gripFor(tip: Pt) -> Pt { place(tip.x, tip.y, STICK, -6, SAIBASHI_PARTS.grip) }
private func cardKnot(_ wrap: Double) -> Pt {
  let off = 1 - min(1, max(0, wrap)), k = RICE_PARTS.top, a = -20 * off * Double.pi / 180
  let r = Pt(CDISH.x + PLATE_PARTS.top.x * CS, CDISH.y + PLATE_PARTS.top.y * CS), rs = CS * 0.9
  return Pt(r.x + (k.x * cos(a) - k.y * sin(a) + 60 * off) * rs, r.y + (k.x * sin(a) + k.y * cos(a) - 70 * off) * rs)
}
private func rice(_ s: CueState) -> (heat: Double, wrap: Double) { (s["rice.heat"], s["rice.wrap"]) }
private func shadowed(_ o: (x: Double, y: Double, s: Double), _ w: Double) { if abs(o.y - Y) < 3 { Shadow(x: o.x, w: w * o.s) } }

let MW_BIND = CueBinding(
  keys: ["mw.open", "mw.on", "mw.disp", "dish.in", "plate", "rice.heat", "rice.wrap", "rice.loose", "rice.amount", "chawan.fill",
         "tool", "stick.open", "scoop", "film", "dish.shift"],
  objects: ["rice", "dish", "bowl"],
  points: [
    "mw.handle": { s in mwHandle(s["mw.open"]) }, "mw.start": { _ in mwStart() },
    "mw.disp": { _ in place(MW.x, MW.y, MW_SCALE, 0, MW_PARTS.display) }, "mw.top": { _ in Pt(MW.x + 40, MW.y - 300) },
    "rice.grip": { s in let o = s.obj("rice"); return Pt(o.x + RICE_PARTS.grip.x * o.s, o.y + RICE_PARTS.grip.y * o.s) },
    "rice.top": { s in let o = s.obj("rice"); return Pt(o.x, o.y - 60) },
    "dish.gripR": { s in let d = s.obj("dish"); return Pt(d.x + PLATE_PARTS.gripR.x * d.s, d.y + PLATE_PARTS.gripR.y * d.s) },
    "dish.gripL": { s in let d = s.obj("dish"); return Pt(d.x - PLATE_PARTS.gripR.x * d.s, d.y + PLATE_PARTS.gripR.y * d.s) },
    "dish.top": { s in let d = s.obj("dish"); return Pt(d.x, d.y - 70 * d.s) },
    "bowl.top": { s in let o = s.obj("bowl"); return Pt(o.x, o.y - 120) },
    "bowl.badge": { s in let o = s.obj("bowl"); return Pt(o.x + 78, o.y - 200) },
    "items": { _ in Pt((CHAWAN.x + RICE_REST.x) / 2 + 40, Y - 190) },
    "timer": { _ in Pt(1530, 420) },
    "c.knot": { s in cardKnot(s["rice.wrap"]) },
    "c.rice": { _ in gripFor(tip: Pt(CDISH.x, CTOP - 14 * CS - 40)) },
    "c.bowl": { _ in gripFor(tip: Pt(CBOWL.x + 6, CTOP - 74 * CS - 30)) },
    "c.away": { s in s.on("tool") ? gripFor(tip: Pt(1760, 640)) : Pt(1720, 560) },
    "c.sleeve": { s in Pt(min(1660, s["C.x"] + 300), 790) },
    "c.dish": { _ in Pt(CDISH.x, CTOP - 100) }, "c.bowl.top": { _ in Pt(CBOWL.x, CTOP - 160) }, "c.hot": { _ in Pt(CBOWL.x + 170, CTOP - 310) },
  ],
  places: ["RICE": (RICE_REST.x, RICE_REST.y, 1), "BOWL": (CHAWAN.x, CHAWAN.y, 1), "PLATE": (PLATE_REST.x, PLATE_REST.y, 1),
           "LIFT": (RICE_REST.x + 10, RICE_REST.y - 90, 1), "PLATETOP": (PLATE_REST.x, PLATE_REST.y + PLATE_PARTS.top.y, 0.9),
           "MWIN": (mwInside().x, mwInside().y, MW_SCALE * DISH_IN_MW_SCALE)],
  draw: { s in
    Shadow(x: MW.x, w: 360)
    MicrowaveSvg(open: s["mw.open"], on: s["mw.on"], display: s.s("mw.disp"), dish: s.on("dish.vis") && s.on("dish.in") ? rice(s) : nil, dishShift: s["dish.shift"])
    if s.on("bowl.vis") { let o = s.obj("bowl"); shadowed(o, 130); Chawan(x: o.x, y: o.y, fill: s["chawan.fill"]) }
    if s.on("plate") { Shadow(x: PLATE_REST.x, w: 190); Plate(x: PLATE_REST.x, y: PLATE_REST.y) }
  },
  front: { s in
    if s.on("rice.vis") { let o = s.obj("rice"); shadowed(o, 140); FrozenRice(x: o.x, y: o.y, scale: o.s, heat: s["rice.heat"], wrap: s["rice.wrap"]) }
    if s.on("dish.vis") && !s.on("dish.in") {
      let d = s.obj("dish"); shadowed(d, 190)
      DishWithRice(x: d.x, y: d.y, scale: d.s, heat: s["rice.heat"], wrap: s["rice.wrap"], loose: s["rice.loose"], amount: s.num["rice.amount"] ?? 1)
    }
  },
  card: { s in
    let palette = useGuide().palette
    rect(x: 600, y: CTOP, width: 1040, height: 60, fill: palette.counter, stroke: palette.ink, strokeWidth: 4)
    Shadow(x: CBOWL.x, y: CTOP, w: 200); Chawan(x: CBOWL.x, y: CBOWL.y, scale: CS, fill: s["chawan.fill"])
    Shadow(x: CDISH.x, y: CTOP, w: 290)
    DishWithRice(x: CDISH.x, y: CDISH.y, scale: CS, heat: 1, wrap: s["rice.wrap"], loose: s["rice.loose"], amount: s.num["rice.amount"] ?? 1)
    let h = Pt(s["C.x"], s["C.y"])
    if s.on("tool") {
      let o = stickOff(s), tip = Pt(h.x - o.x, h.y - o.y)
      Saibashi(x: tip.x, y: tip.y, scale: STICK, angle: -6 + 4 * sin(s["C.dx"] * 0.02), open: s["stick.open"])
      if s.on("scoop") { ellipse(cx: tip.x + 6, cy: tip.y - 6, rx: 30, ry: 18, fill: "#fbf7ee", stroke: palette.ink, strokeWidth: 4) }
    }
    if s["film"] > 0.02 {
      g(opacity: s["film"], transform: [.translate(h.x, h.y)]) {
        path("M -6 0 C -40 20 -90 50 -120 96 L -40 120 C -20 80 6 40 8 4 Z", fill: "#dfeef5", stroke: "#9fb8c4", strokeWidth: 3, fillOpacity: 0.5)
      }
    }
  }
)
