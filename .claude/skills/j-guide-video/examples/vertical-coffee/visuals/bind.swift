// この動画の道具の描き方と名前 (全工程のキューで共通)。縦型: 上が全景 (カウンター y 1120)、下が拡大カード (y 1235〜1655)
import JGVKit

private let Y = 1120.0, MUG = Pt(560, 1120), MS = 0.6, JAR = Pt(720, 1120)
private let CMUG = Pt(420, 1610), CMS = 1.1, CJAR = Pt(800, 1610)
private let POWDER: Paint = "#4a2f1d", COFFEE: Paint = "#6b4429"
private func kettleAt(_ s: CueState, _ part: Pt) -> Pt { let k = s.obj("kettle"); return place(k.x, k.y, k.s, s["kettle.a"], flipPart(part)) }
private func drink(_ s: CueState) -> (Double, Paint) {
  let fill = max(0.06 * s["mug.powder"], s["mug.fill"])
  return (fill, s["mug.fill"] > 0.1 ? Paint("#2e1b10").mix(COFFEE, s["mixed"]) : POWDER)
}
private func spoonTip(_ s: CueState) -> Pt { Pt(s["C.x"] - SPOON_PARTS.grip.x * 1.4 + SPOON_PARTS.bowl.x * 1.4, s["C.y"]) }

let BIND = CueBinding(
  keys: ["kettle.a", "pour", "mug.fill", "mug.powder", "mixed", "jar.lid", "spoon", "spoon.full"],
  objects: ["kettle"],
  points: [
    "kettle.handle": { s in kettleAt(s, KETTLE_PARTS.handle) },
    "mug.top": { _ in Pt(MUG.x, Y - 230) }, "mug.badge": { _ in Pt(MUG.x + 120, Y - 260) },
    "c.sleeve": { s in Pt(min(1000, s["C.x"] + 260), 1700) },
    "c.jar": { _ in Pt(CJAR.x + 110, CJAR.y - 170) }, "c.mug": { _ in Pt(CMUG.x + 150, CMUG.y - 230) },
    "c.mugin": { _ in Pt(CMUG.x + 150, CMUG.y - 160) }, "c.steam": { _ in Pt(CMUG.x, CMUG.y - 230) },
  ],
  places: ["KREST": (900, Y, 0.55), "POUR": (714, 962, 0.55)],
  draw: { s in
    let (fill, color) = drink(s)
    Shadow(x: MUG.x, w: 160); Mug(x: MUG.x, y: MUG.y, scale: MS, fill: fill, drink: color)
    Shadow(x: JAR.x, w: 110); Canister(x: JAR.x, y: JAR.y, scale: 0.5, label: "珈琲")
  },
  front: { s in
    let k = s.obj("kettle")
    if abs(k.y - Y) < 3 { Shadow(x: k.x, w: 200) }
    Kettle(x: k.x, y: k.y, scale: k.s, angle: s["kettle.a"], flip: true)
    if s.on("pour") { Stream(from: kettleAt(s, KETTLE_PARTS.spout), to: Pt(MUG.x + 10, Y - 100), width: 10) }
  },
  card: { s in
    let palette = useGuide().palette
    rect(x: 50, y: CMUG.y, width: 980, height: 60, fill: palette.counter, stroke: palette.ink, strokeWidth: 4)
    let (fill, color) = drink(s)
    Mug(x: CMUG.x, y: CMUG.y, scale: CMS, fill: fill, drink: color)
    if s.on("pour") { Stream(from: Pt(CMUG.x + 20, 1235), to: Pt(CMUG.x + 20, CMUG.y - 120), width: 18) }
    Canister(x: CJAR.x, y: CJAR.y, scale: 0.9, label: "珈琲", lidOpen: s["jar.lid"])
    if s.on("spoon") && s["C.x"] < 1000 {
      Spoon(x: s["C.x"] - SPOON_PARTS.grip.x * 1.4, y: s["C.y"], scale: 1.4, leaves: false)
      if s["spoon.full"] > 0.02 { let t = spoonTip(s); ellipse(cx: t.x, cy: t.y - 6, rx: 26, ry: 12, fill: POWDER, opacity: s["spoon.full"]) }
    }
  }
)
