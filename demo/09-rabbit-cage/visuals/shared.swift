// 全シーン共通の配置 (ケージ・サークル・取り出した物の置き場) と、物や手を順番に動かす track() (track と Move は kit の Motion.swift)
import JGVKit

let CAGE = Pt(1330, GUIDE.counterY)
let PEN = Pt(680, GUIDE.counterY)
/// ケージのローカル座標 → 画面座標
func cage(_ p: Pt) -> Pt { Pt(CAGE.x + p.x, CAGE.y + p.y) }
let SLOT = Parts([
  "toilet": cage(CAGE_PARTS.toilet),
  "bowl": cage(CAGE_PARTS.bowl),
  "toy": cage(CAGE_PARTS.toy),
  "rabbit": cage(CAGE_PARTS.rabbit),
])
/// ケージから出した物の置き場 (カウンター上)
let OUT = Parts([
  "toilet": Pt(915, GUIDE.counterY),
  "bowl": Pt(1692, GUIDE.counterY),
  "toy": Pt(1785, GUIDE.counterY),
])
let RABBIT_SCALE = 0.85
let IN_PEN = Pt(PEN.x + 10, GUIDE.counterY - 8)
/// うさぎを抱える両手の位置 (うさぎの原点からの相対)
func holdL(_ r: Pt) -> Pt { Pt(r.x - 40, r.y - 14) }
func holdR(_ r: Pt) -> Pt { Pt(r.x + 52, r.y - 18) }
/// 拡大カードの人物の右手 (カードの縁を指す) と下ろした位置
let POINT = Pt(615, 515)
let LOW = Pt(440, 680)

/// moves のどれかの最中か
func moving(_ frame: Double, _ fps: Double, _ moves: [Move]) -> Bool {
  moves.contains { m in frame >= m.at && frame < m.at + m.dur * fps }
}

/// ケージの中に置いてある物
struct Inside {
  var toilet = false
  var bowl = false
  var toy = false
}

/// ケージ一式。inside で中に置いてある物、rabbit でうさぎを中に描く。content は金網の奥 (中身の層) に描く
func CageSet(
  door: Double = 0, hay: Double = 0.3, fresh: Bool = false, water: Double = 0.3, dirt: Double = 0,
  inside: Inside = Inside(toilet: true, bowl: true, toy: true), clean: Bool = false, rabbit: Bool = false, nibble: Bool = false,
  rabbitAt: Pt? = nil, _ content: () -> Void = {}
) {
  g {
    CageBack(x: CAGE.x, y: CAGE.y, hay: hay, fresh: fresh, water: water, dirt: dirt)
    if inside.toilet { Toilet(x: SLOT.toilet.x, y: SLOT.toilet.y, pellets: clean ? 0 : 0.7, soil: clean ? 0 : 1) }
    if inside.bowl { FoodBowl(x: SLOT.bowl.x, y: SLOT.bowl.y, scale: 0.85, food: clean ? 1 : 0.3) }
    if inside.toy { Toy(x: SLOT.toy.x, y: SLOT.toy.y) }
    if rabbit {
      let at = rabbitAt ?? SLOT.rabbit
      Rabbit(x: at.x, y: at.y, scale: RABBIT_SCALE, nibble: nibble)
    }
    content()
    CageFront(x: CAGE.x, y: CAGE.y, door: door)
  }
}
