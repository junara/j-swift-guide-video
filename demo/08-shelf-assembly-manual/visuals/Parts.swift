// 部品を確認する: 段ボール箱 → 部品が分解図で並び、句ごとに部品リストの行が光る
import Foundation
import JGVKit

private let EXPLODE: [PartId: Off3] = [
  .D: (0, -26, 0),
  .AL: (-24, 0, 0),
  .B: (0, 0, 0),
  .C1: (0, 30, -6),
  .C2: (0, 30, 6),
  .T: (0, 0, 18),
  .AR: (24, 0, 0),
]

func Parts(_ props: Props) {
  let n = useNarration()
  let boxOut = interpolate(n.frame, [n.at(0, 0.8), n.endOf(0)], [0, 1], .clamp)
  let at = [n.atPhrase(1, 0), n.atPhrase(1, 1), n.atPhrase(1, 2), n.atPhrase(1, 3), n.atPhrase(1, 4)]
  let show = { (i: Int) -> Double in interpolate(n.frame, [at[i] - 4, at[i] + 6], [0, 1], .clamp) }
  let groups: [PartId: Int] = [.AL: 0, .AR: 0, .B: 1, .T: 1, .C1: 2, .C2: 2, .D: 3]
  var state: [PartId: PartState] = [:]
  for (id, off) in EXPLODE { state[id] = PartState(off: off, opacity: max(boxOut * 0.25, show(groups[id]!))) }
  let tag = { (id: PartId, dx: Double, dy: Double, i: Int) in
    let c = partCenter(id, EXPLODE[id]!)
    let r = id.rawValue
    let letter = r.hasPrefix("C") ? "C" : id == .T ? "B" : String(r.prefix(1))
    PartTag(x: c.x + dx, y: c.y + dy, letter: letter, to: c, opacity: show(i))
  }
  Stage {
    // 段ボール箱 (1 行目)
    g(opacity: 1 - boxOut) {
      IsoBox(iso: ISO, x: -10, y: -5, z: 0, w: 60, d: 45, h: 25, fill: "#d8b98e")
    }
    ColorBox(state: state)
    tag(.AL, -120, -60, 0)
    tag(.AR, 120, -80, 0)
    tag(.T, 110, -70, 1)
    tag(.B, -150, 60, 1)
    tag(.C1, -170, 40, 2)
    tag(.D, 140, -40, 3)
    g(opacity: show(4)) {
      for i in 0..<8 {
        Screw(x: 1120 + Double(i % 4) * 46, y: 800 + Double(i / 4) * 30, scale: 1.2)
      }
    }
    PartsList(
      x: LIST.x,
      y: LIST.y,
      w: LIST.w,
      items: [
        PartsListItem(letter: "A", name: n.t("parts.A", "側板"), qty: "×2", at: at[0]),
        PartsListItem(letter: "B", name: n.t("parts.B", "天板・底板"), qty: "×2", at: at[1]),
        PartsListItem(letter: "C", name: n.t("parts.C", "棚板"), qty: "×2", at: at[2]),
        PartsListItem(letter: "D", name: n.t("parts.D", "背板"), qty: "×1", at: at[3]),
        PartsListItem(letter: "E", name: n.t("parts.E", "ネジ"), qty: "×16", at: at[4]),
      ]
    )
  }
}
