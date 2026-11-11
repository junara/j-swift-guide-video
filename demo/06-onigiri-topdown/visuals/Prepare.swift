// 材料を用意する: 句ごとに ご飯 → 塩 → 梅干し → 海苔 が置かれる → 手を洗う
import Foundation
import JGVKit

func Prepare(_ props: Props) {
  let n = useNarration()
  let bowlIn = useSlide(n.atPhrase(0, 0, -0.1))
  let saltIn = useSlide(n.atPhrase(0, 1, -0.1))
  let umeIn = useSlide(n.atPhrase(0, 2, -0.1))
  let noriIn = useSlide(n.atPhrase(0, 3, -0.1))
  // 2 行目: 両手をこすり合わせる (泡)
  let hands = interpolate(n.frame, [n.at(1, -0.2), n.at(1, 0.4)], [0, 1], .clamp)
  let rub = sin(n.frame * 0.5) * 30 * hands
  let c = Pt(1060, 640)
  Stage {
    TableItems(bowlIn: bowlIn, saltIn: saltIn, umeIn: umeIn, noriIn: noriIn)
    if bowlIn > 0.8 { Steam(x: BOWL.x, y: BOWL.y - 40, count: 3, height: 120, opacity: 0.4) }
    if hands > 0 {
      g(opacity: hands) {
        TopHand(from: ARM_L, to: Pt(c.x - 40 + rub, c.y + (1 - hands) * 300), angle: 70, side: .L)
        TopHand(from: ARM_R, to: Pt(c.x + 40 - rub, c.y + 10 + (1 - hands) * 300), angle: -70, side: .R)
        for i in 0..<4 {
          let di = Double(i)
          let k = jsMod(n.sec * 1.5 + di / 4, 1)
          circle(cx: c.x - 90 + di * 60, cy: c.y - 90 - k * 60, r: 10 + di * 2, fill: "#bfe3f0", stroke: "#7fb3c6", strokeWidth: 3, opacity: (1 - k) * hands)
        }
      }
    }
    Callout(x: 1060, y: 340, text: "手をきれいに洗う", at: n.at(1, 0.3))
  }
}
